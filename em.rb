require 'rubygems'
require 'eventmachine'

module EventMachine
  def self.start(background = nil, &block)
    if EM::reactor_running?
      # Attention: here we loose the ability to catch 
      # immediate connection errors.
      EM::next_tick(&block)
      sleep unless background # this blocks the thread as it was inside a reactor
    else
      if background
        Thread.abort_on_exception = true
        $em_reactor_thread = Thread.new do
          EM::old_run(&block)
        end
      else
        EM::old_run(&block)
      end
    end
  end

  class << self
    alias :old_run :run
    alias :run :start
  end unless EM.respond_to? :old_run
end

EM.epoll
