require 'xmpp4em'

started = Time.now
users = {}
connected = 0
num = Integer(ARGV[0])
num = 1000 if num < 1

EM.epoll

EM.run{
  num.times do |i|
    p i
    users[i] = XMPP4EM::Client.new("test_#{i}@localhost", 'test', :auto_register => true)
    users[i].on(:login) do
      connected += 1
      p ['connected', i, "#{connected} of #{num}"]
  
      if connected == num
        p ['done', Time.now - started]
        EM.stop_event_loop
      end
    end
    users[i].on(:disconnect) do
      p ['disconnected', i]
    end
  
    users[i].connect('localhost', 5222)
  end
}
