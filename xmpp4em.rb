require 'stringio'
require 'rexml/parsers/sax2parser'

require 'rubygems'

require 'xmpp4r/idgenerator'
require 'xmpp4r/xmppstanza'
require 'xmpp4r/iq'
require 'xmpp4r/message'
require 'xmpp4r/presence'
require 'xmpp4r/sasl'

require 'em'

module XMPP4EM
  class NotConnected < Exception; end

  class Connection < EventMachine::Connection
    def initialize host
      @host = host
      @client = nil
    end
    attr_accessor :client

    def connection_completed
      log 'connected'
      @stream_features, @stream_mechanisms = {}, []
      init
    end
    attr_reader :stream_features

    include EventMachine::XmlPushParser

    def start_element name, attrs
      e = REXML::Element.new(name)
      e.add_attributes attrs
      
      @current = @current.nil? ? e : @current.add_element(e)

      if @current.name == 'stream' and not @started
        @started = true
        process
        @current = nil
      end
    end
    
    def end_element name
      if name == 'stream:stream' and @current.nil?
        @started = false
      else
        if @current.parent
          @current = @current.parent
        else
          process
          @current = nil
        end
      end
    end

    def characters text
      @current.text = @current.text.to_s + text if @current
    end

    def error *args
      p ['error', *args]
    end

    def receive_data data
      log "<< #{data}"
      super
    end

    def send data, &blk
      log ">> #{data}"
      send_data data.to_s
    end

    def unbind
      log 'disconnected'
    end

    def init
      send "<?xml version='1.0' ?>" unless @started
      @started = false
      send "<stream:stream xmlns:stream='http://etherx.jabber.org/streams' xmlns='jabber:client' xml:lang='en' version='1.0' to='#{@host}'>"
    end

    private

    def log data
      return
      puts
      puts data
    end

    def process
      if @current.namespace('').to_s == '' # REXML namespaces are always strings
        @current.add_namespace(@streamns)
      end

      case @current.prefix
      when 'stream'

        case @current.name
          when 'stream'
            @streamid = @current.attributes['id']
            @streamns = @current.namespace('') if @current.namespace('')

            # Hack: component streams are basically client streams.
            # Someday we may want to create special stanza classes
            # for components/s2s deriving from normal stanzas but
            # posessing these namespaces
            @streamns = 'jabber:client' if @streamns == 'jabber:component:accept'

          when 'features'
            @stream_features, @stream_mechanisms = {}, []
            @current.each { |e|
              if e.name == 'mechanisms' and e.namespace == 'urn:ietf:params:xml:ns:xmpp-sasl'
                e.each_element('mechanism') { |mech|
                  @stream_mechanisms.push(mech.text)
                }
              else
                @stream_features[e.name] = e.namespace
              end
            }
        end

        stanza = @current

      else
        # Any stanza, classes are registered by XMPPElement::name_xmlns
        begin
          stanza = Jabber::XMPPStanza::import(@current)
        rescue Jabber::NoNameXmlnsRegistered
          stanza = @current
        end
      end

      @client.receive(stanza)
    end
  end

  class Client
    def initialize user, pass, opts = {}
      @user = user
      @pass = pass
      @connection = nil
      @authenticated = false

      @auth_callback = nil
      @id_callbacks  = {}

      @callbacks = {
        :message   => [],
        :presence  => [],
        :iq        => [],
        :exception => [],
        :login     => []
      }

      @opts = { :auto_register => false }.merge(opts)
    end
    attr_reader :connection

    def jid
      @jid ||= if @user.kind_of?(Jabber::JID)
                 @user
               else
                 @user =~ /@/ ? Jabber::JID.new(@user) : Jabber::JID.new(@user, 'localhost')
               end
    end

    def connect host = jid.domain, port = 5222
      EM.run(true) do
        EM.connect host, port, Connection, host do |conn|
          @connection = conn
          conn.client = self
        end
      end
    end

    def connected?
      @connection and !@connection.error?
    end

    def login &blk
      Jabber::SASL::new(self, 'PLAIN').auth(@pass)
      @auth_callback = blk if block_given?
    end

    def register &blk
      reg = Jabber::Iq.new_register(jid.node, @pass)
      reg.to = jid.domain
      
      send(reg){ |reply|
        blk.call( reply.type == :result ? :success : reply.type )
      }
    end

    def send_msg to, msg
      send Jabber::Message::new(to, msg).set_type(:chat)
    end

    def send data, &blk
      raise NotConnected unless connected?

      if block_given? and data.is_a? Jabber::XMPPStanza
        if data.id.nil?
          data.id = Jabber::IdGenerator.instance.generate_id
        end

        @id_callbacks[ data.id ] = blk
      end

      @connection.send(data)
    end

    def close
      @connection.close_connection_after_writing
      @connection = nil
    end
    alias :disconnect :close

    def receive stanza
      if stanza.kind_of? Jabber::XMPPStanza and stanza.id and blk = @id_callbacks[ stanza.id ]
        @id_callbacks.delete stanza.id
        blk.call(stanza)
        return
      end

      case stanza.name
      when 'features'
        unless @authenticated
          login do |res|
            # log ['login response', res].inspect
            if res == :failure and @opts[:auto_register]
              register do |res|
                #p ['register response', res]
                login unless res == :error
              end
            end
          end

        else
          if @connection.stream_features.has_key? 'bind'
            iq = Jabber::Iq.new(:set)
            bind = iq.add REXML::Element.new('bind')
            bind.add_namespace @connection.stream_features['bind']

            send(iq){ |reply|
              if reply.type == :result and jid = reply.first_element('//jid') and jid.text
                # log ['new jid is', jid.text].inspect
                @jid = Jabber::JID.new(jid.text)
              end
            }
          end

          if @connection.stream_features.has_key? 'session'
            iq = Jabber::Iq.new(:set)
            session = iq.add REXML::Element.new('session')
            session.add_namespace @connection.stream_features['session']

            send(iq){ |reply|
              if reply.type == :result

                @callbacks[:login].each do |blk|
                  blk.call(stanza)
                end
              end
            }
          end
        end

        return

      when 'success', 'failure'
        if stanza.name == 'success'
          @authenticated = true
          @connection.reset_parser
          @connection.init
        end

        @auth_callback.call(stanza.name.to_sym) if @auth_callback
        return
      end

      case stanza
      when Jabber::Message
        @callbacks[:message].each do |blk|
          blk.call(stanza)
        end

      when Jabber::Iq
        @callbacks[:iq].each do |blk|
          blk.call(stanza)
        end

      when Jabber::Presence
        @callbacks[:presence].each do |blk|
          blk.call(stanza)
        end
      end

    end
    
    def on type, &blk
      @callbacks[type] << blk
    end
    
    def add_message_callback  (&blk) on :message,   &blk end
    def add_presence_callback (&blk) on :presence,  &blk end
    def add_iq_callback       (&blk) on :iq,        &blk end
    def on_exception          (&blk) on :exception, &blk end
  end
end
