require 'helper'
require 'set'
require 'example-apps'

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
