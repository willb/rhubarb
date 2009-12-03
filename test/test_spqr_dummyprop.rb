require 'helper'
require 'set'

class QmfDummyProp
  include ::SPQR::Manageable

  def QmfDummyProp.find_by_id(oid)
    @qmf_dps ||= [QmfDummyProp.new]
    @qmf_dps[0]
  end
  
  def QmfDummyProp.find_all
    @qmf_dps ||= [QmfDummyProp.new]
    @qmf_dps
  end
  
  def service_name
    "DummyPropService"
  end
  
  spqr_property :service_name, :lstr

  spqr_class :QmfDummyProp
  spqr_package :example
end

class TestSpqrDummyProp < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end

  def test_property_basic
    app_setup QmfDummyProp

    obj = $console.objects(:class=>"QmfDummyProp")[0]
    assert_equal "DummyPropService", obj[:service_name]
  end
end
