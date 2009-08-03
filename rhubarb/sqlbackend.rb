#!/usr/bin/env ruby

require 'set'
require 'time'
require 'sqlite3'

# module GridConfigStore

class Persistence
  @@backend = nil
  
  def self.open_db(filename)
    self.db = SQLite3::Database.new(filename)
  end

  def self.db
    @@backend
  end

  def self.db=(db)
    @@backend = db
    db.results_as_hash = true
    db.type_translation = true
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

  @@columns = [Column.new(:id, :integer, [:primary_key])]
  @@colnames = Set.new []
  @@constraints = []
  @@dirtied = {}
  
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
    res = Persistence::execute("select * from #{table_name} where #{id} = ?", id)
    if res.size == 0
      nil
    else
      self.new res[0]
    end
  end
  
  def self.declare_column(name, kind, *quals)
    find_method_name = "find_by_#{name}".to_sym
    get_method_name = "#{name}".to_sym
    set_method_name = "#{name}=".to_sym

    # add a find for this column (a class method)
    self.class.instance_eval do 
      define_method find_method_name do |arg|
        Persistence::execute("select * from #{table_name} where #{name} = ?", arg)
        res.map {|row| self.new(true, row)}
      end
    end

    # add accessors
    define_method get_method_name do
      freshen
      @tuple["#{name}"]
    end

    define_method set_method_name do |arg|
      @tuple["#{name}"] = arg
      @@dirtied[@id] = Time.now.utc
      Persistence::execute("update #{table_name} set #{name} = ? where id = ?", arg, @id)
    end

    @colnames.merge([name])
    @columns.push(Column.new(name, kind, quals))
  end

  def self.declare_constraint(name, kind, *details)
    info = details.join(" ")
    @constraints.push("#{name} #{kind} #{info}")
  end

  def self.insert(*args)
    cols = @colnames.intersection args[0].keys
    colspec = (cols.map {|col| col.to_s}).join(", ")
    valspec = (cols.map {|col| col.inspect}).join(", ")

    Persistence::db.transaction do |db|
      db.execute("insert into #{table_name} (#{colspec}) values (#{valspec})", args)
      find(db.last_insert_row_id)
    end
  end

  def self.create_table
    cols = @columns.join(", ")
    consts = @constraints.join(", ")
    "create table #{table_name} ( #{cols} #{consts} );"
  end

  def initialize(tup)
    @backed = true
    @tuple = tup
    @expired_after = Time.now.utc
    @id = @tuple["id"]
    @@dirtied[@id] ||= @expired_after
  end
  

  ## begin private methods
  private
  def freshen
    if @expired_after < @@dirtied[@id]
      @tuple = Persistence::execute("select * from #{table_name} where #{id} = ?", @id)
      @expired_after = Time.now.utc
    end
    nil
  end
end

# end
