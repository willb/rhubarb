require 'helper'
require 'set'

class QmfIntegerProp
  include ::SPQR::Manageable 

  SIZE = 12
 
  def initialize(oid)
    @int_id = oid
  end

  def spqr_object_id
    @int_id
  end
  
  def QmfIntegerProp.gen_objects(ct)
    objs = []
    ct.times do |x|
      objs << (new(x))
    end
    objs
  end

  def QmfIntegerProp.find_by_id(oid)
    @qmf_ips ||= gen_objects SIZE
    @qmf_ips[oid]
  end
  
  def QmfIntegerProp.find_all
    @qmf_ips ||= gen_objects SIZE
    @qmf_ips
  end

  def next(args)
    args['result'] = QmfIntegerProp.find_by_id((oid + 1) % QmfIntegerProp::SIZE)
  end
  
  spqr_expose :next do |args|
    args.declare :result, :objId, :out
  end

  spqr_property :int_id, :int

  spqr_class :QmfIntegerProp
  spqr_package :example
end

class TestSpqrIntegerProp < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end

  def test_reference_returning_method
    app_setup QmfIntegerProp
    
    objs = $console.objects(:class=>"QmfIntegerProp")
    
    objs.size.times do |x|
      expected = objs[(x + 1) % QmfIntegerProp::SIZE]
      actual = objs[x].next.result
      assert_equal expected, actual
    end
  end

  def test_property_identities
    app_setup QmfIntegerProp

    objs = $console.objects(:class=>"QmfIntegerProp")
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
      obj = $console.objects(:class=>"QmfIntegerProp", 'int_id'=>x)[0]
      assert_equal x, obj[:int_id]
    end
  end
end
