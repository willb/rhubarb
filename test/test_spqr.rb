require 'helper'
require 'qmf'

class QmfHello
  include ::SPQR::Manageable

  def hello(args)
    args["result"] = "Hello, #{args['name']}!"
  end

  def self.find_by_id(oid)
    @@singleton ||= QmfHello.new
    @@singleton
  end

  def self.find_all
    @@singleton ||= QmfHello.new
    [@@singleton]
  end

  spqr_expose :hello do |args|
    args.declare :name, :lstr, :in
    args.declare :result, :lstr, :out
  end
  
  spqr_package :example
  spqr_class :QmfHello
end

module QmfTestHelpers
  def app_setup(*classes)
    @app = SPQR::App.new(:loglevel => :fatal)
    @app.register *classes
    @child_pid = fork do 
      # replace stdin/stdout/stderr
      $stdin.reopen("/dev/null", "r")
      $stdout.reopen("/dev/null", "w")
      $stderr.reopen("/dev/null", "w")

      @app.main
    end
    
    sleep 1
    @connection = Qmf::Connection.new(Qmf::ConnectionSettings.new)
    @console = Qmf::Console.new
    @broker = @console.add_connection(@connection)
    @broker.wait_for_stable
  end

  def teardown
    @connection = nil
    Process.kill(1, @child_pid) if @child_pid
  end
end

class TestSpqr < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end
  
  def test_hello_objects
    app_setup QmfHello
    objs = @console.objects(:class=>"QmfHello")
    assert objs.size > 0
  end

  def test_hello_call
    app_setup QmfHello
    obj = @console.objects(:class=>"QmfHello")[0]
    
    val = obj.hello("ruby").result
    args = { 'name' => 'ruby' }
    QmfHello.find_by_id(0).hello(args)

    expected = args['result']

    assert_equal expected, val
  end
end
