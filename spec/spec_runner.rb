require 'bacon'
$:.unshift File.dirname(__FILE__) + '/..'
require 'xmpp4em'

shared 'eventmachine' do
  $bacon_thread = Thread.current
  def wait
    Thread.stop
    @timer = EM::Timer.new(10) do
      wake
      should.flunk('waited too long')
    end
  end
  def wake
    $bacon_thread.wakeup
    @timer.cancel if @timer
  end
end

EM.run{
  Thread.new{
    Thread.abort_on_exception = true
    require 'xmpp4em_spec'
    EM.stop_event_loop
  }
}