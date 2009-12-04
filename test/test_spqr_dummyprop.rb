require 'helper'
require 'set'
require 'example-apps'

class TestSpqrDummyProp < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
  end

  def test_property_basic
    app_setup QmfDummyProp

    obj = $console.objects(:class=>"QmfDummyProp", :agent=>@ag)[0]
    assert_equal "DummyPropService", obj[:service_name]
  end
end
