require 'rubygems'
require 'test/unit'
require 'qmf'
require 'timeout'
require 'thread'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'spqr/spqr'
require 'spqr/app'
require 'rhubarb/rhubarb'

module QmfTestHelpers
  DEBUG = false
  
  class AgentNotifyHandler < Qmf::ConsoleHandler
    def initialize
      @q = Queue.new
    end
    
    def queue
      @q
    end

    def agent_added(agent)
      puts "GOT AN AGENT:  #{agent}" if DEBUG
      @q << agent
    end
  end

  def app_setup(*classes)
    unless $broker
      $notify_handler = AgentNotifyHandler.new
      $connection = Qmf::Connection.new(Qmf::ConnectionSettings.new)
      $console = Qmf::Console.new($notify_handler)
      $broker = $console.add_connection($connection)
    end
      
    @app = SPQR::App.new(:loglevel => (DEBUG ? :debug : :fatal))
    @app.register *classes
    @child_pid = fork do 
      unless DEBUG
        # replace stdin/stdout/stderr
        $stdin.reopen("/dev/null", "r")
        $stdout.reopen("/dev/null", "w")
        $stderr.reopen("/dev/null", "w")
      end

      @app.main
    end
    
    $broker.wait_for_stable

    Timeout.timeout(5) do
      k = ""
      begin
        @ag = $notify_handler.queue.pop
        k = @ag.key
        puts "GOT A KEY:  #{k}" if DEBUG
      end until k != "1.0"

      # XXX
      sleep 0.45
      puts "ESCAPING FROM TIMEOUT" if DEBUG
    end

  end

  def teardown
    Process.kill(9, @child_pid) if @child_pid
  end
end

class Test::Unit::TestCase
end
