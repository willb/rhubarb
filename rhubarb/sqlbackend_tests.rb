require 'sqlbackend'
require 'test/unit'

class TestClass < Table
  declare_column :foo, :integer
  declare_column :bar, :string
end

class TestClass2 < Table
  declare_column :fred, :integer
  declare_column :barney, :string
end

class TC3 < Table
  declare_column :ugh, :datetime
  declare_column :yikes, :integer
  declare_constraint :yikes_pos, check("yikes >= 0")
end

class TC4 < Table
  declare_column :t1, :integer, references(TestClass)
  declare_column :t2, :integer, references(TestClass2)
end

def eigenclass(k)
  class << k; self end
end

class BackendBasicTests < Test::Unit::TestCase
  def setup
    Persistence::open(":memory:")
    TestClass.create_table
    TestClass2.create_table
    TC3.create_table
    TC4.create_table
  end

  def teardown
    Persistence::close()
  end

  def test_persistence_setup
    assert Persistence::db.type_translation, "type translation not enabled for db"
    assert Persistence::db.results_as_hash, "rows-as-hashes not enabled for db"
  end

  def test_reference_ctor_klass
    r = Reference.new(TestClass)
    assert(r.referent == TestClass, "Referent of managed reference instance incorrect")
    assert(r.column == "row_id", "Column of managed reference instance incorrect")
    assert(r.to_s == "references TestClass(row_id)", "string representation of managed reference instance incorrect")
    assert(r.managed_ref?, "managed reference should return true for managed_ref?")
  end

  def test_reference_ctor_string
    r = Reference.new("TestClass")
    assert(r.referent == "TestClass", "Referent of string-backed reference instance incorrect")
    assert(r.column == "row_id", "Column of string-backed reference instance incorrect")
    assert(r.to_s == "references TestClass(row_id)", "string representation of string-backed reference instance incorrect")
    assert(r.managed_ref? == false, "unmanaged reference should return false for managed_ref?")
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
        assert TestClass2.instance_methods.include?(m), "#{m} method not declared in TestClass2"
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
        klass = class << TestClass2; self end
        assert klass.instance_methods.include?(m), "#{m} method not declared in TestClass2's eigenclass"
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
    assert(TestClass2.columns.size == 3, "TestClass2 has wrong number of columns")
  end

  def test_table_column_size
    if Table.respond_to? :columns
      assert(Table.columns.size == 0, "Table has wrong number of columns")
    end
  end

  def test_constraints_size
    {Table => 0, TestClass => 0, TestClass2 => 0, TC3 => 1}.each do |klass, cts|
      if klass.respond_to? :constraints
        assert(klass.constraints.size == cts, "#{klass} has wrong number of constraints")
      end
    end
  end

  def test_cols_and_constraints_understood
    [TestClass, TestClass2, TC3, TC4].each do |klass|
      assert(klass.respond_to?(:constraints), "#{klass} should have accessor for constraints")
      assert(klass.respond_to?(:columns), "#{klass} should have accessor for columns")
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

  def test_create_multiples
    tc_list = [nil]
    [1,2,3,4,5,6,7,8,9].each do |num|
      tc_list.push TestClass.create(:foo => num, :bar => "argh#{num}")
    end

    [1,2,3,4,5,6,7,8,9].each do |num|
      assert(tc_list[num].foo == num, "multiple TestClass.create invocations should return records with proper foo values")
      assert(tc_list[num].bar == "argh#{num}", "multiple TestClass.create invocations should return records with proper bar values")

      tmp = TestClass.find(num)

      assert(tmp.foo == num, "multiple TestClass.create invocations should add records with proper foo values to the db")
      assert(tmp.bar == "argh#{num}", "multiple TestClass.create invocations should add records with proper bar values to the db")
    end
  end

  def test_delete
    range = [1,2,3,4,5,6,7,8,9]
    range.each do |num|
      TestClass.create(:foo => num, :bar => "argh#{num}")
    end
    
    assert(TestClass.count == range.size, "correct number of rows inserted prior to delete")

    TestClass.find(2).delete

    assert(TestClass.count == range.size - 1, "correct number of rows inserted after delete")
  end

  def test_count_base
    assert(TestClass.count == 0, "a new table should have no rows")
  end

  def test_count_inc
    range = [1,2,3,4,5,6,7,8,9]
    range.each do |num|
      TestClass.create(:foo => num, :bar => "argh#{num}")
      assert(TestClass.count == num, "table row count should increment after each row create")
    end
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

  def test_find_by_id_bogus
    tc = TestClass.find(1)
    assert(tc == nil, "TestClass table should be empty")
  end

  def test_create_and_find_by_foo
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    result = TestClass.find_by_foo(2)
    tc = result[0]
    assert(result.size == 1, "TestClass.find_by_foo(2) should return exactly one result")
    assert(tc.foo == 2, "tc.foo (found by foo) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by foo) should have the value \"argh\"")
  end

  def test_create_and_find_first_by_foo
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    tc = (TestClass.find_first_by_foo(2))
    assert(tc.foo == 2, "tc.foo (found by foo) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by foo) should have the value \"argh\"")
  end

  def test_create_and_find_by_bar
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    result = TestClass.find_by_bar("argh")
    tc = result[0]
    assert(result.size == 1, "TestClass.find_by_bar(\"argh\") should return exactly one result")
    assert(tc.foo == 2, "tc.foo (found by bar) should have the value 2")
    assert(tc.bar == "argh", "tc.bar (found by bar) should have the value \"argh\"")
  end
  
  def test_create_and_find_first_by_bar
    vals = {:foo => 2, :bar => "argh"}
    TestClass.create(vals)
    
    tc = (TestClass.find_first_by_bar("argh"))
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
  
  def test_reference_tables
    assert(TC4.refs.size == 2, "TC4 should have 2 refs, instead has #{TC4.refs.size}")
  end

  def test_reference_classes
    t_vals = []
    t2_vals = []
    
    [1,2,3,4,5,6,7,8,9].each do |n| 
      t_vals.push({:foo => n, :bar => "item-#{n}"})
      TestClass.create t_vals[-1]
    end

    [9,8,7,6,5,4,3,2,1].each do |n| 
      t2_vals.push({:fred => n, :barney => "barney #{n}"})
      TestClass2.create t2_vals[-1]
    end

    [1,2,3,4,5,6,7,8,9].each do |n|
      m = 10-n
      k = TC4.create(:t1 => n, :t2 => m)
      p k
      p k.inspect
      assert(k.t1.class == TestClass, "k.t1.class is #{k.t1.class}; should be TestClass")
      assert(k.t2.class == TestClass2, "k.t2.class is #{k.t2.class}; should be TestClass2")
    end
  end

  def test_references_simple
    t_vals = []
    t2_vals = []
    
    [1,2,3,4,5,6,7,8,9].each do |n| 
      t_vals.push({:foo => n, :bar => "item-#{n}"})
      TestClass.create t_vals[-1]
    end

    [9,8,7,6,5,4,3,2,1].each do |n| 
      t2_vals.push({:fred => n, :barney => "barney #{n}"})
      TestClass2.create t2_vals[-1]
    end

    [1,2,3,4,5,6,7,8,9].each do |n|
      k = TC4.create(:t1 => n, :t2 => (10 - n))
      assert(k.t1.foo == k.t2.fred, "references don't work")
    end
  end
end
