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
  attr_reader :referent, :column, :options

  # Creates a new Reference object, modeling a foreign-key relationship to another table.  +klass+ is a class that extends Table; +options+ is a hash of options, which include
  # +:column => + _name_::  specifies the name of the column to reference in +klass+ (defaults to row id)
  # +:on_delete => :cascade+:: specifies that deleting the referenced row in +klass+ will delete all rows referencing that row through this reference
  def initialize(klass, options={})
    @referent = klass
    @options = options
    @options[:column] ||= "row_id"
    @column = options[:column]
  end

  def to_s
    trigger = ""
    trigger = " on delete cascade" if options[:on_delete] == :cascade
    "references #{@referent}(#{@column})#{trigger}"
  end

  def managed_ref?
    # XXX?
    return false if referent.class == String
    referent.ancestors.include? Table
  end
end

class Table
  attr_reader :row_id
  attr_reader :created
  attr_reader :updated
  
  # Returns the name of the database table modeled by this class.
  def self.table_name
    self.name.downcase  
  end
  
  # Models a foreign-key relationship. +options+ is a hash of options, which include
  # +:column => + _name_::  specifies the name of the column to reference in +klass+ (defaults to row id)
  # +:on_delete => :cascade+:: specifies that deleting the referenced row in +klass+ will delete all rows referencing that row through this reference
  def self.references(table, options={})
    Reference.new(table, options)
  end

  # Models a CHECK constraint.
  def self.check(condition)
    "check (#{condition})"
  end
  
  # Returns an object corresponding to the row with the given ID, or +nil+ if no such row exists.
  def self.find(id)
    tup = self.find_tuple(id)
    return self.new(tup) if tup
    nil
  end

  # Declares a query method named +name+ and adds it to this class.  The query method returns a list of objects corresponding to the rows returned by executing "+SELECT * FROM+ _table_ +WHERE+ _query_" on the database.
  def self.declare_query(name, query)
    klass = (class << self; self end)
    klass.class_eval do
      define_method name.to_s do |*args|
        # handle reference parameters
        args = args.map {|x| (x.row_id if x.class.ancestors.include? Table) or x}
        
        res = Persistence::execute("select * from #{table_name} where #{query}", args)
        res.map {|row| self.new(row)}        
      end
    end
  end

  # Declares a custom query method named +name+, and adds it to this class.  The custom query method returns a list of objects corresponding to the rows returned by executing +query+ on the database.  +query+ should select all fields (with +SELECT *+).  If +query+ includes the string +\_\_TABLE\_\_+, it will be expanded to the table name.  Typically, you will want to use +declare\_query+ instead; this method is most useful for self-joins.
  def self.declare_custom_query(name, query)
    klass = (class << self; self end)
    klass.class_eval do
      define_method name.to_s do |*args|
        # handle reference parameters
        args = args.map {|x| (x.row_id if x.class.ancestors.include? Table) or x}
        
        res = Persistence::execute(query.gsub("__TABLE__", "#{self.table_name}"), args)
        # XXX:  should freshen each row?
        res.map {|row| self.new(row) }        
      end
    end
  end
  
  def self.declare_index_on(*fields)
    @creation_callbacks << Proc.new do
      idx_name = "idx_#{self.table_name}__#{fields.join('__')}__#{@creation_callbacks.size}"
      creation_cmd = "create index #{idx_name} on #{self.table_name} (#{fields.join(', ')})"
      Persistence.execute(creation_cmd)
    end if fields.size > 0
  end

  # Adds a column named +cname+ to this table declaration, and adds the following methods to the class:
  # * accessors for +cname+, called +cname+ and +cname=+
  # * +find\_by\_cname+ and +find\_first\_by\_cname+ methods, which return a list of rows and the first row that have the given value for +cname+, respectively
  # If the column references a column in another table (given via a +references(...)+ argument to +quals+), then add triggers to the database to ensure referential integrity and cascade-on-delete (if specified)
  def self.declare_column(cname, kind, *quals)
    ensure_accessors
    
    find_method_name = "find_by_#{cname}".to_sym
    find_first_method_name = "find_first_by_#{cname}".to_sym
    get_method_name = "#{cname}".to_sym
    set_method_name = "#{cname}=".to_sym
    
    # does this column reference another table?
    rf = quals.find {|q| q.class == Reference}
    if rf
      self.refs[cname] = rf
    end

    # add a find for this column (a class method)
    klass = (class << self; self end)
    klass.class_eval do 
      define_method find_method_name do |arg|
        res = Persistence::execute("select * from #{table_name} where #{cname} = ?", arg)
        res.map {|row| self.new(row)}
      end

      define_method find_first_method_name do |arg|
        res = Persistence::execute("select * from #{table_name} where #{cname} = ?", arg)
        return self.new(res[0]) if res.size > 0
        nil
      end
    end

    self.colnames.merge([cname])
    self.columns << Column.new(cname, kind, quals)
    
    # add accessors
    define_method get_method_name do
      freshen
      return @tuple["#{cname}"] if @tuple
      nil
    end
    
    if not rf
      define_method set_method_name do |arg|
        @tuple["#{cname}"] = arg
        update cname, arg
      end      
    else
      # this column references another table; create a set 
      # method that can handle either row objects or row IDs
      define_method set_method_name do |arg|
        freshen
        
        arg_id = nil

        if arg.class == Fixnum
          arg_id = arg
          arg = rf.referent.find arg_id
        else
          arg_id = arg.row_id
        end
        @tuple["#{cname}"] = arg
        
        update cname, arg_id
      end
      
      # Finally, add appropriate triggers to ensure referential integrity.
      # If rf has an on_delete trigger, also add the necessary
      # triggers to cascade deletes. 
      # Note that we do not support update triggers, since the API does 
      # not expose the capacity to change row IDs.
      
      self.creation_callbacks << Proc.new do 
        Persistence::db.execute_batch("CREATE TRIGGER refint_insert_#{self.table_name}_#{rf.referent.table_name}_#{self.creation_callbacks.size} BEFORE INSERT ON \"#{self.table_name}\" WHEN new.\"#{cname}\" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM \"#{rf.referent.table_name}\" WHERE new.\"#{cname}\" == \"#{rf.column}\") BEGIN SELECT RAISE(ABORT, 'constraint failed'); END;")
        
        Persistence::db.execute_batch("CREATE TRIGGER refint_delete_#{self.table_name}_#{rf.referent.table_name}_#{self.creation_callbacks.size} BEFORE DELETE ON \"#{rf.referent.table_name}\" WHEN EXISTS (SELECT 1 FROM \"#{self.table_name}\" WHERE old.\"#{rf.column}\" == \"#{cname}\") BEGIN DELETE FROM \"#{self.table_name}\" WHERE \"#{cname}\" = old.\"#{rf.column}\"; END;") if rf.options[:on_delete] == :cascade
      end
    end
  end
  
  # Declares a constraint.  Only check constraints are supported; see
  # the check method.
  def self.declare_constraint(cname, kind, *details)
    ensure_accessors
    info = details.join(" ")
    @constraints << "constraint #{cname} #{kind} #{info}"
  end
  
  # Creates a new row in the table with the supplied column values.
  # May throw a SQLite3::SQLException.
  def self.create(*args)
    new_row = args[0]
    new_row[:created] = new_row[:updated] = Time.now.utc.tv_sec
    
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
#      p stmt
      db.execute(stmt, new_row)
      res = find(db.last_insert_row_id)
    end
    res
  end
  
  # Returns a string consisting of the DDL statement to create a table
  # corresponding to this class. 
  def self.table_decl
    cols = columns.join(", ")
    consts = constraints.join(", ")
    if consts.size > 0
      "create table #{table_name} (#{cols}, #{consts});"
    else
      "create table #{table_name} (#{cols});"
    end
  end
  
  # Creates a table in the database corresponding to this class.
  def self.create_table
    Persistence::execute(table_decl)
    @creation_callbacks.each {|func| func.call}
  end

  # Returns true if the row backing this object has been deleted from the database
  def deleted?
    freshen
    not @tuple
  end
  
  # Initializes a new instance backed by a tuple of values.  Do not call this directly. 
  # Create new instances with the create or find methods.
  def initialize(tup)
    @backed = true
    @tuple = tup
    mark_fresh
    @row_id = @tuple["row_id"]
    resolve_referents
    self.class.dirtied[@row_id] ||= @expired_after
    self
  end
  
  # Deletes the row corresponding to this object from the database; 
  # invalidates =self= and any other objects backed by this row
  def delete
    Persistence::execute("delete from #{self.class.table_name} where row_id = ?", @row_id)
    mark_dirty
    @tuple = nil
    @row_id = nil
  end

  # Returns the number of rows in the table backing this class
  def self.count
    result = Persistence::execute("select count(row_id) from #{table_name}")[0]
    result[0].to_i
  end

  protected
  def self.find_tuple(id)
    res = Persistence::execute("select * from #{table_name} where row_id = ?", id)
    if res.size == 0
      nil
    else
      res[0]
    end
  end

  ## Begin private methods

  private
  
  # Fetches updated attribute values from the database if necessary
  def freshen
    if needs_refresh?
      @tuple = self.class.find_tuple(@row_id)
      @row_id = nil if not @tuple
      mark_fresh
      resolve_referents
    end
  end
  
  # True if the underlying row in the database is inconsistent with the state 
  # of this object, whether because the row has changed, or because this object has no row id
  def needs_refresh?
    if not @row_id 
      @tuple != nil
    else
      @expired_after < self.class.dirtied[@row_id]
    end
  end
  
  # Mark this row as dirty so that any other objects backed by this row will 
  # update from the database before their attributes are inspected
  def mark_dirty
    self.class.dirtied[@row_id] = Time.now.utc
  end
  
  # Mark this row as consistent with the underlying database as of now
  def mark_fresh
    @expired_after = Time.now.utc
  end
  
  # Helper method to update the row in the database when one of our fields changes
  def update(attr_name, value)
    mark_dirty
    Persistence::execute("update #{self.class.table_name} set #{attr_name} = ?, updated = ? where row_id = ?", value, Time.now.utc.tv_sec, @row_id)
  end
  
  # Resolve any fields that reference other tables, replacing row ids with referred objects
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

  # Ensure that all the necessary accessors on our class instance are defined 
  # and that all metaclass fields have the appropriate values
  def self.ensure_accessors
    # Define singleton accessors
    if not self.respond_to? :columns
      class << self
        # Arrays of columns, column names, and column constraints.
        # Note that colnames does not contain id, created, or updated.
        # The API purposefully does not expose the ability to create a
        # row with a given id, and created and updated values are
        # maintained automatically by the API.
        attr_accessor :columns, :colnames, :constraints, :dirtied, :refs, :creation_callbacks
      end
    end

    # Ensure singleton fields are initialized
    self.columns ||= [Column.new(:row_id, :integer, [:primary_key]), Column.new(:created, :integer, []), Column.new(:updated, :integer, [])]
    self.colnames ||= Set.new [:created, :updated]
    self.constraints ||= []
    self.dirtied ||= {}
    self.refs ||= {}
    self.creation_callbacks ||= []
  end
end
