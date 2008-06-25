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
end