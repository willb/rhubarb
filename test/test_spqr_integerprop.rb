require 'helper'
require 'set'
require 'example-apps'

class TestSpqrIntegerProp < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end

  def test_reference_returning_method
    app_setup QmfIntegerProp
    
    objs = $console.objects(:class=>"QmfIntegerProp", :agent=>@ag)
    
    objs.size.times do |x|
      expected = objs[(x + 1) % QmfIntegerProp::SIZE]
      actual = objs[x].next.result
      assert_equal expected, actual
    end
  end

  def test_property_identities
    app_setup QmfIntegerProp

    objs = $console.objects(:class=>"QmfIntegerProp", :agent=>@ag)
    ids = Set.new

    objs.each do |obj| 
      ids << obj[:int_id] 
    end

    assert_equal objs.size, ids.size
    
    objs.size.times do |x|
      assert ids.include?(x), "ids should include #{x}, which is less than #{objs.size}"
    end
  end

  def test_find_objs_by_props
    app_setup QmfIntegerProp

    sz = QmfIntegerProp::SIZE

    sz.times do |x|
      obj = $console.objects(:class=>"QmfIntegerProp", 'int_id'=>x, :agent=>@ag)[0]
      assert_equal x, obj[:int_id]
    end
  end
end
