describe 'XMPP4EM' do
  behaves_like 'eventmachine'

  @foo = XMPP4EM::Client.new('foo@localhost', 'test', :auto_register => true)
  @bar = XMPP4EM::Client.new('bar@localhost', 'test', :auto_register => true)

  should 'login to an xmpp server' do
    @foo.on(:login) do
      @foo.send Jabber::Presence.new
      wake
    end

    @foo.connect
    wait

    @foo.should.be.connected?
  end

  should 'send messages to others' do
    @bar.on(:login) do
      @bar.send Jabber::Presence.new do
        wake
      end
    end

    received = nil
    @bar.on(:message) do |msg|
      received = msg.first_element_text('//body')
      wake
    end

    @bar.connect
    wait

    @foo.send_msg 'bar@localhost', 'hello'
    wait

    received.should == 'hello'
  end

  should 'fire disconnect callback and reconnect' do
    user = XMPP4EM::Client.new('user@localhost', 'user', :auto_register => true)
    user.on(:disconnect){ wake }
    user.connect 'localhost', 5333 # invalid port
    wait

    user.should.not.be.connected?

    user.instance_variable_get('@callbacks')[:disconnect] = []
    user.connection.port = 5222
    user.on(:login){ wake }
    user.reconnect
    wait

    user.should.be.connected?
  end
end
