require 'helper'
require 'set'
require 'example-apps'

class TestSpqrClicker < Test::Unit::TestCase
  include QmfTestHelpers

  def setup
    @child_pid = nil
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

  def test_statistics_postquery
    app_setup QmfClicker

    x = 0
    
    9.times do
      obj = $console.objects(:class=>"QmfClicker")[0]
      assert_equal x, obj[:clicks]
      
      obj.click({})
      x = x.succ
    end
  end

  def test_statistics_postupdate
    app_setup QmfClicker

    x = 0
    obj = $console.objects(:class=>"QmfClicker")[0]
    
    9.times do
      obj.update
      assert_equal x, obj[:clicks]
      
      obj.click({})
      x = x.succ
    end
  end
end
