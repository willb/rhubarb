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
    @quals = quals
  end
  
  def to_s
    qualifiers = @quals.join(" ").gsub("_", " ")
    if qualifiers == ""
      "#@name #@kind"
    else
      "#@name #@kind #{qualifiers}"
    end
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
  
  def self.references(table, column)
    "references #{table} (#{column})"
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
    
    self.columns ||= [Column.new(:row_id, :integer, [:primary_key])]
    self.colnames ||= Set.new []
    self.constraints ||= []
    self.dirtied ||= {}
    
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
    @constraints.push("#{name} #{kind} #{info}")
  end
  
  def self.create(*args)
    cols = colnames.intersection args[0].keys
    colspec = (cols.map {|col| col.to_s}).join(", ")
    valspec = (cols.map {|col| col.inspect}).join(", ")
    res = nil
    
    Persistence::db.transaction do |db|
      db.execute("insert into #{table_name} (#{colspec}) values (#{valspec})", args)
      res = find(db.last_insert_row_id)
    end
    res
  end
  
  def self.table_decl
    cols = columns.join(", ")
    consts = constraints.join(", ")
    "create table #{table_name} (#{cols} #{consts});"
  end
  
  def self.create_table
    Persistence::execute(table_decl)
  end
  
  def initialize(tup)
    @backed = true
    @tuple = tup
    @expired_after = Time.now.utc
    @row_id = @tuple["row_id"]
    self.class.dirtied[@row_id] ||= @expired_after
  end
  
  ## Begin private methods

  private
  def freshen
    if @expired_after < self.class.dirtied[@row_id]
      @tuple = Persistence::execute("select * from #{self.class.table_name} where #{row_id} = ?", @row_id)[0]
      @expired_after = Time.now.utc
    end
  end
  
  def self.ensure_accessors
    # ensure that all the necessary methods on our class instance are defined
    if not self.respond_to? :columns
      class << self
        attr_accessor :columns, :colnames, :constraints, :dirtied 
      end
    end
  end
end

