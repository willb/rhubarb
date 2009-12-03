require 'rubygems'
require 'test/unit'
require 'qmf'
require 'timeout'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'spqr/spqr'
require 'spqr/app'
require 'rhubarb/rhubarb'

module QmfTestHelpers
  DEBUG = false
  
  def app_setup(*classes)
    $connection = Qmf::Connection.new(Qmf::ConnectionSettings.new) unless $connection
    $console = Qmf::Console.new unless $console
    $broker = $console.add_connection($connection) unless $broker

    pr, pw = IO.pipe
    
    @app = SPQR::App.new(:loglevel => DEBUG ? :debug : :fatal, :notifier => pw)
    @app.register *classes
    @child_pid = fork do 
      pr.close

      unless DEBUG
        # replace stdin/stdout/stderr
        $stdin.reopen("/dev/null", "r")
        $stdout.reopen("/dev/null", "w")
        $stderr.reopen("/dev/null", "w")
      end

      @app.main
    end

    sleep 0.35

    $broker.wait_for_stable

    Timeout.timeout(15) do
      pw.close
      pr.read
    end

  end

  def teardown
    Process.kill(9, @child_pid) if @child_pid
  end
end

class Test::Unit::TestCase
end
