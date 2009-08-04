require 'sqlbackend'
require 'test/unit'

class TestClass < Table
  declare_column :foo, :integer
  declare_column :bar, :string
end

class TC2 < Table
  declare_column :fred, :integer
  declare_column :barney, :string
end

def eigenclass(k)
  class << k; self end
end

class BackendBasicTests < Test::Unit::TestCase
  def setup
    Persistence::open(":memory:")
    TestClass.create_table
    TC2.create_table
  end

  def teardown
    Persistence::close()
  end

  def test_persistence_setup
    assert Persistence::db.type_translation, "type translation not enabled for db"
    assert Persistence::db.results_as_hash, "rows-as-hashes not enabled for db"
  end

  def test_instance_methods
    ["foo", "bar"].each do |prefix|
      ["#{prefix}", "#{prefix}="].each do |m|
        assert TestClass.instance_methods.include?(m), "#{m} method not declared in TestClass"
      end
    end
  end

  def test_instance_methods2
    ["fred", "barney"].each do |prefix|
      ["#{prefix}", "#{prefix}="].each do |m|
        assert TC2.instance_methods.include?(m), "#{m} method not declared in TC2"
      end
    end
  end

  def test_instance_methods_neg
    ["fred", "barney"].each do |prefix|
      ["#{prefix}", "#{prefix}="].each do |m|
        bogus_include = TestClass.instance_methods.include? m
        assert(bogus_include == false, "#{m} method declared in TestClass; shouldn't be")
      end
    end
  end

  def test_instance_methods_dont_include_class_methods
    ["foo", "bar"].each do |prefix|
      ["find_by_#{prefix}", "find_first_by_#{prefix}"].each do |m|
        bogus_include = TestClass.instance_methods.include? m
        assert(bogus_include == false, "#{m} method declared in TestClass; shouldn't be")
      end
    end
  end

  def test_class_methods
    ["foo", "bar"].each do |prefix|
      ["find_by_#{prefix}", "find_first_by_#{prefix}"].each do |m|
        klass = class << TestClass; self end
        assert klass.instance_methods.include?(m), "#{m} method not declared in TestClass' eigenclass"
      end
    end
  end
  
  def test_class_methods2
    ["fred", "barney"].each do |prefix|
      ["find_by_#{prefix}", "find_first_by_#{prefix}"].each do |m|
        klass = class << TC2; self end
        assert klass.instance_methods.include?(m), "#{m} method not declared in TC2's eigenclass"
      end
    end
  end
    
  def test_table_class_methods_neg
    ["foo", "bar", "fred", "barney"].each do |prefix|
      ["find_by_#{prefix}", "find_first_by_#{prefix}"].each do |m|
        klass = class << Table; self end
        bogus_include = klass.instance_methods.include?(m)
        assert(bogus_include == false, "#{m} method declared in Table's eigenclass; shouldn't be")
      end
    end
  end

  def test_class_methods_neg
    ["fred", "barney"].each do |prefix|
      ["find_by_#{prefix}", "find_first_by_#{prefix}"].each do |m|
        klass = class << TestClass; self end
        bogus_include = klass.instance_methods.include?(m)
        assert(bogus_include == false, "#{m} method declared in TestClass' eigenclass; shouldn't be")
      end
    end
  end

  def test_column_size
    assert(TestClass.columns.size == 3, "TestClass has wrong number of columns")
  end

  def test_tc2_column_size
    assert(TC2.columns.size == 3, "TC2 has wrong number of columns")
  end

  def test_table_column_size
    if Table.respond_to? :columns
      assert(Table.columns.size == 0, "Table has wrong number of columns")
    end
  end

  def test_column_contents
    [:row_id, :foo, :bar].each do |col|
      assert(TestClass.columns.map{|c| c.name}.include?(col), "TestClass doesn't contain column #{col}")
    end
  end
  
  def test_create_proper_type
    tc = TestClass.create(:foo => 1, :bar => "argh")
    assert(tc.class == TestClass, "TestClass.create should return an instance of TestClass")
  end

  def test_create_proper_values
    vals = {:foo => 1, :bar => "argh"}
    tc = TestClass.create(vals)
    assert(tc.foo == 1, "tc.foo (newly-created) should have the value 1")
    assert(tc.bar == "argh", "tc.bar (newly-created) should have the value \"argh\"")
  end
  
  def test_create_and_find_by_id
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    tc = TestClass.find(1)
    assert(tc.foo == 2, "tc.foo (found by id) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by id) should have the value \"argh\"")
  end

  def test_create_and_find_by_foo
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    tc = (TestClass.find_by_foo(2))[0]
    assert(tc.foo == 2, "tc.foo (found by foo) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by foo) should have the value \"argh\"")
  end

  def test_create_and_find_by_bar
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    tc = (TestClass.find_by_bar("argh"))[0]
    assert(tc.foo == 2, "tc.foo (found by bar) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by bar) should have the value \"argh\"")
  end
  
  def test_create_and_update_modifies_object
    vals = {:foo => 1, :bar => "argh"}
    TestClass.create(vals)
    
    tc = TestClass.find(1)
    tc.foo = 2
    assert("#{tc.foo}" == "2", "tc.foo should have the value 2 after modifying object")
  end
  
  def test_create_and_update_modifies_db
    vals = {:foo => 1, :bar => "argh"}
    TestClass.create(vals)
    
    tc = TestClass.find(1)
    tc.foo = 2
    
    tc_fresh = TestClass.find(1)
    assert(tc_fresh.foo == 2, "foo value in first row of db should have the value 2 after modifying tc object")
  end
  
  def test_create_and_update_freshen
    vals = {:foo => 1, :bar => "argh"}
    TestClass.create(vals)
    
    tc_fresh = TestClass.find(1)    
    tc = TestClass.find(1)
    
    tc.foo = 2
    
    assert(tc_fresh.foo == 2, "object backed by db row isn't freshened")
  end
  
end
