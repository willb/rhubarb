require 'helper'
require 'qmf'

class QmfHello
  include ::SPQR::Manageable

  def QmfHello.find_by_id(oid)
    @@qmf_hellos ||= [QmfHello.new]
    @@qmf_hellos[0]
  end
  
  def QmfHello.find_all
    @@qmf_hellos ||= [QmfHello.new]
    @@qmf_hellos
  end

  def hello(args)
    args["result"] = "Hello, #{args['name']}!"
  end

  spqr_expose :hello do |args|
    args.declare :name, :lstr, :in
    args.declare :result, :lstr, :out
  end
  
  spqr_package :example
  spqr_class :QmfHello
end

class QmfClicker
   include ::SPQR::Manageable

   def QmfClicker.find_by_id(oid)
     @singleton ||= QmfClicker.new
     @singleton
   end
  
   def QmfClicker.find_all
     @singleton ||= QmfClicker.new
     [@singleton]
   end

   def initialize
     @clicks = 0
   end

   def click(args)
     @clicks = @clicks.succ
   end
  
   spqr_expose :click do |args| 
   end

   spqr_statistic :clicks, :int

   spqr_package :example
   spqr_class :QmfClicker
 end

module QmfTestHelpers
  def app_setup(*classes)
    pr, pw = IO.pipe
    @app = SPQR::App.new(:loglevel => :fatal, :notifier => pw)
    @app.register *classes
    @child_pid = fork do 
      pr.close

      # replace stdin/stdout/stderr
      $stdin.reopen("/dev/null", "r")
      $stdout.reopen("/dev/null", "w")
      $stderr.reopen("/dev/null", "w")

      @app.main
    end

    sleep 0.25

    pw.close
    pr.read

    $connection = Qmf::Connection.new(Qmf::ConnectionSettings.new) unless $connection
    $console = Qmf::Console.new unless $console
    $broker = $console.add_connection($connection) unless $broker

    $broker.wait_for_stable
  end

  def teardown
    Process.kill(9, @child_pid) if @child_pid
  end
end

class TestSpqr < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end

  def test_hello_objects
    app_setup QmfHello
    objs = $console.objects(:class=>"QmfHello")
    assert objs.size > 0
  end

  def test_hello_call
    app_setup QmfHello
    obj = $console.objects(:class=>"QmfHello")[0]
    
    val = obj.hello("ruby").result
    args = { 'name' => 'ruby' }
    QmfHello.find_by_id(0).hello(args)

    expected = args['result']

    assert_equal expected, val
  end

  def test_no_param_method
    app_setup QmfClicker

    assert_nothing_raised do
      obj = $console.objects(:class=>"QmfClicker")[0]
      
      obj.click({})
    end
  end

  def test_statistics_empty
    app_setup QmfClicker

    obj = $console.objects(:class=>"QmfClicker")[0]
    assert_equal "clicks", obj.statistics[0][0].name
    assert_equal 0, obj[:clicks]
  end

end
