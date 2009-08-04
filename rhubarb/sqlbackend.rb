#!/usr/bin/env ruby

require 'rubygems'
require 'set'
require 'time'
require 'sqlite3'

class Persistence
  @@backend = nil
  
  def self.open(filename)
    self.db = SQLite3::Database.new(filename)
  end

  def self.close
    self.db.close
    self.db = nil
  end

  def self.db
    @@backend
  end

  def self.db=(d)
    @@backend = d
    self.db.results_as_hash = true if d != nil
    self.db.type_translation = true if d != nil
  end
  
  def self.execute(*query)
    db.execute(*query) if db != nil
  end
end

class Column
  attr_reader :name

  def initialize(name, kind, quals)
    @name, @kind = name, kind
    @quals = quals.map {|x| x.to_s.gsub("_", " ") if x.class == Symbol}
    @quals.map 
  end
  
  def to_s
    qualifiers = @quals.join(" ")
    if qualifiers == ""
      "#@name #@kind"
    else
      "#@name #@kind #{qualifiers}"
    end
  end
end

class Reference
  attr_reader :referent
  attr_reader :column

  # klass is a class that extends Table
  def initialize(klass, col="row_id")
    @referent = klass
    @column = col
  end

  def to_s
    "references #{@referent}(#{@column})"
  end

  def managed_ref?
    return false if referent.class == String
    referent.ancestors.include? Table
  end
end

class Table
  # Arrays of columns, column names, and column constraints.
  # Note that colnames does not contain id.  The API purposefully
  # does not expose the ability to create a row with a given id
  
  attr_reader :row_id
  
  def self.table_name
    self.name.downcase  
  end
  
  def self.references(table, column="row_id")
    Reference.new(table, column)
  end

  def self.check(condition)
    "check (#{condition})"
  end

  def self.on(event, action)
    "on #{event} #{action}"
  end
  
  def self.find(id)
    res = Persistence::execute("select * from #{table_name} where row_id = ?", id)
    if res.size == 0
      nil
    else
      self.new res[0]
    end
  end
  
  def self.declare_column(name, kind, *quals)
    ensure_accessors
    
    find_method_name = "find_by_#{name}".to_sym
    find_first_method_name = "find_first_by_#{name}".to_sym
    get_method_name = "#{name}".to_sym
    set_method_name = "#{name}=".to_sym
    
    # does this column reference another table?
    rf = quals.find {|q| q.class == Reference}
    if rf
      self.refs[name] = rf
    end

    # add a find for this column (a class method)
    klass = (class << self; self end)
    klass.class_eval do 
      define_method find_method_name do |arg|
        res = Persistence::execute("select * from #{table_name} where #{name} = ?", arg)
        res.map {|row| self.new(row)}
      end

      define_method find_first_method_name do |arg|
        res = Persistence::execute("select * from #{table_name} where #{name} = ?", arg)
        self.new(res[0])
      end
    end

    self.colnames.merge([name])
    self.columns.push(Column.new(name, kind, quals))
    
    # add accessors
    define_method get_method_name do
      freshen
      @tuple["#{name}"]
    end
    
    define_method set_method_name do |arg|
      @tuple["#{name}"] = arg
      self.class.dirtied[@row_id] = Time.now.utc
      Persistence::execute("update #{self.class.table_name} set #{name} = ? where row_id = ?", arg, @row_id)
    end
  end
  
  def self.declare_constraint(name, kind, *details)
    ensure_accessors
    info = details.join(" ")
    @constraints.push("constraint #{name} #{kind} #{info}")
  end
  
  def self.create(*args)
    new_row = args[0]
    cols = colnames.intersection new_row.keys
    colspec = (cols.map {|col| col.to_s}).join(", ")
    valspec = (cols.map {|col| col.inspect}).join(", ")
    res = nil
    
    # resolve any references in the args
    new_row.each do |k,v|
      new_row[k] = v.row_id if v.class.ancestors.include? Table
    end

    Persistence::db.transaction do |db|
      stmt = "insert into #{table_name} (#{colspec}) values (#{valspec})"
      db.execute(stmt, new_row)
      res = find(db.last_insert_row_id)
    end
    res
  end
  
  def self.table_decl
    cols = columns.join(", ")
    consts = constraints.join(", ")
    if consts.size > 0
      "create table #{table_name} (#{cols}, #{consts});"
    else
      "create table #{table_name} (#{cols});"
    end
  end
  
  def self.create_table
    Persistence::execute(table_decl)
  end
  
  def initialize(tup)
    @backed = true
    @tuple = tup
    @expired_after = Time.now.utc
    @row_id = @tuple["row_id"]
    resolve_referents
    self.class.dirtied[@row_id] ||= @expired_after
  end
  
  def delete
    Persistence::execute("delete from #{self.class.table_name} where row_id = ?", @row_id)
    @tuple = nil
  end

  def self.count
    result = Persistence::execute("select count(row_id) from #{table_name}")[0]
    result[0].to_i
  end

  ## Begin private methods

  private
  def freshen
    if @expired_after < self.class.dirtied[@row_id]
      @tuple = Persistence::execute("select * from #{self.class.table_name} where row_id = ?", @row_id)[0]
      @expired_after = Time.now.utc
    end
  end
  
  def resolve_referents
    refs = self.class.refs

    refs.each do |c,r|
      c = c.to_s
      if r.referent == self.class and @tuple[c] == row_id
        @tuple[c] = self
      else
        row = r.referent.find @tuple[c]
        @tuple[c] = row if row
      end
    end
  end

  def self.ensure_accessors
    # ensure that all the necessary accessors on our class instance are defined
    if not self.respond_to? :columns
      class << self
        attr_accessor :columns, :colnames, :constraints, :dirtied, :refs
      end
    end

    # ... and that all fields have the appropriate values
    self.columns ||= [Column.new(:row_id, :integer, [:primary_key])]
    self.colnames ||= Set.new []
    self.constraints ||= []
    self.dirtied ||= {}
    self.refs ||= {}
  end
end

