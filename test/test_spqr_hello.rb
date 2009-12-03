require 'helper'
require 'set'

class QmfHello
  include ::SPQR::Manageable
  
  def QmfHello.find_by_id(oid)
    @qmf_hellos ||= [QmfHello.new]
    @qmf_hellos[0]
  end
  
  def QmfHello.find_all
    @qmf_hellos ||= [QmfHello.new]
    @qmf_hellos
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

class TestSpqrHello < Test::Unit::TestCase
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
end
