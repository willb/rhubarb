# Rhubarb is a simple persistence layer for Ruby objects and SQLite.
# For now, see the test cases for example usage.
#
# Copyright (c) 2009 Red Hat, Inc.
#
# Author:  William Benton (willb@redhat.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

require 'rubygems'
require 'set'
require 'time'
require 'sqlite3'

module Rhubarb

module SQLBUtil
  def self.timestamp(tm=nil)
    tm ||= Time.now.utc
    (tm.tv_sec * 1000000) + tm.tv_usec
  end
end
    

module Persistence
  class DbCollection < Hash
    alias orig_set []=
    
    def []=(k,v)
      v.results_as_hash = true if v
      v.type_translation = true if v
      orig_set(k,v)
    end
  end
  
  @@dbs = DbCollection.new
  
  def self.open(filename, which=:default)
    dbs[which] = SQLite3::Database.new(filename)
  end

  def self.close(which=:default)
    if dbs[which]
      dbs[which].close
      dbs.delete(which)
    end
  end

  def self.db
    dbs[:default]
  end
  
  def self.db=(d)
    dbs[:default] = d
  end

  def self.dbs
    @@dbs
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

  # Creates a new Reference object, modeling a foreign-key relationship to another table.  +klass+ is a class that includes Persisting; +options+ is a hash of options, which include
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
    referent.ancestors.include? Persisting
  end
end


# Methods mixed in to the class object of a persisting class
module PersistingClassMixins 
  # Returns the name of the database table modeled by this class.
  # Defaults to the name of the class (sans module names)
  def table_name
    @table_name ||= self.name.split("::").pop.downcase  
  end
  
  # Enables setting the table name to a custom name
  def declare_table_name(nm)
    @table_name = nm
  end

  # Models a foreign-key relationship. +options+ is a hash of options, which include
  # +:column => + _name_::  specifies the name of the column to reference in +klass+ (defaults to row id)
  # +:on_delete => :cascade+:: specifies that deleting the referenced row in +klass+ will delete all rows referencing that row through this reference
  def references(table, options={})
    Reference.new(table, options)
  end

  # Models a CHECK constraint.
  def check(condition)
    "check (#{condition})"
  end
  
  # Returns an object corresponding to the row with the given ID, or +nil+ if no such row exists.
  def find(id)
    tup = self.find_tuple(id)
    return self.new(tup) if tup
    nil
  end
  
  alias find_by_id find

  def find_by(arg_hash)
    arg_hash = arg_hash.dup
    valid_cols = self.colnames.intersection arg_hash.keys
    select_criteria = valid_cols.map {|col| "#{col.to_s} = #{col.inspect}"}.join(" AND ")
    arg_hash.each {|k,v| arg_hash[k] = v.row_id if v.respond_to? :row_id}

    self.db.execute("select * from #{table_name} where #{select_criteria} order by row_id", arg_hash).map {|tup| self.new(tup) }
  end

  # args contains the following keys
  #  * :group_by maps to a list of columns to group by (mandatory)
  #  * :select_by maps to a hash mapping from column symbols to values (optional)
  #  * :version maps to some version to be considered "current" for the purposes of this query; that is, all rows later than the "current" version will be disregarded (optional, defaults to latest version)
  def find_freshest(args)
    args = args.dup
    
    args[:version] ||= SQLBUtil::timestamp
    args[:select_by] ||= {}
    
    query_params = {}
    query_params[:version] = args[:version]
    
    select_clauses = ["created <= :version"]

    valid_cols = self.colnames.intersection args[:select_by].keys

    valid_cols.map do |col|
      select_clauses << "#{col.to_s} = #{col.inspect}"
      val = args[:select_by][col]
      val = val.row_id if val.respond_to? :row_id
      query_params[col] = val
    end

    group_by_clause = "GROUP BY " + args[:group_by].join(", ")
    where_clause = "WHERE " + select_clauses.join(" AND ")
    projection = self.colnames - [:created]
    join_clause = projection.map do |column|
      "__fresh.#{column} = __freshest.#{column}"
    end

    projection << "MAX(created) AS __current_version"
    join_clause << "__fresh.__current_version = __freshest.created"

    query = "
SELECT __freshest.* FROM (
  SELECT #{projection.to_a.join(', ')} FROM (
    SELECT * from #{table_name} #{where_clause}
  ) #{group_by_clause}
) as __fresh INNER JOIN #{table_name} as __freshest ON
  #{join_clause.join(' AND ')}
  ORDER BY row_id
"

    self.db.execute(query, query_params).map {|tup| self.new(tup) }
  end

  # Does what it says on the tin.  Since this will allocate an object for each row, it isn't recomended for huge tables.
  def find_all
    self.db.execute("SELECT * from #{table_name}").map {|tup| self.new(tup)}
  end

  def delete_all
    self.db.execute("DELETE from #{table_name}")
  end

  # Declares a query method named +name+ and adds it to this class.  The query method returns a list of objects corresponding to the rows returned by executing "+SELECT * FROM+ _table_ +WHERE+ _query_" on the database.
  def declare_query(name, query)
    klass = (class << self; self end)
    klass.class_eval do
      define_method name.to_s do |*args|
        # handle reference parameters
        args = args.map {|x| (x.row_id if x.class.ancestors.include? Persisting) or x}
        
        res = self.db.execute("select * from #{table_name} where #{query}", args)
        res.map {|row| self.new(row)}        
      end
    end
  end

  # Declares a custom query method named +name+, and adds it to this class.  The custom query method returns a list of objects corresponding to the rows returned by executing +query+ on the database.  +query+ should select all fields (with +SELECT *+).  If +query+ includes the string +\_\_TABLE\_\_+, it will be expanded to the table name.  Typically, you will want to use +declare\_query+ instead; this method is most useful for self-joins.
  def declare_custom_query(name, query)
    klass = (class << self; self end)
    klass.class_eval do
      define_method name.to_s do |*args|
        # handle reference parameters
        args = args.map {|x| (x.row_id if x.class.ancestors.include? Persisting) or x}
        
        res = self.db.execute(query.gsub("__TABLE__", "#{self.table_name}"), args)
        # XXX:  should freshen each row?
        res.map {|row| self.new(row) }        
      end
    end
  end
  
  def declare_index_on(*fields)
    @creation_callbacks << Proc.new do
      idx_name = "idx_#{self.table_name}__#{fields.join('__')}__#{@creation_callbacks.size}"
      creation_cmd = "create index #{idx_name} on #{self.table_name} (#{fields.join(', ')})"
      self.db.execute(creation_cmd)
    end if fields.size > 0
  end

  # Adds a column named +cname+ to this table declaration, and adds the following methods to the class:
  # * accessors for +cname+, called +cname+ and +cname=+
  # * +find\_by\_cname+ and +find\_first\_by\_cname+ methods, which return a list of rows and the first row that have the given value for +cname+, respectively
  # If the column references a column in another table (given via a +references(...)+ argument to +quals+), then add triggers to the database to ensure referential integrity and cascade-on-delete (if specified)
  def declare_column(cname, kind, *quals)
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
        res = self.db.execute("select * from #{table_name} where #{cname} = ?", arg)
        res.map {|row| self.new(row)}
      end

      define_method find_first_method_name do |arg|
        res = self.db.get_first_row("select * from #{table_name} where #{cname} = ?", arg)
        return self.new(res) if res
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
        @ccount ||= 0

        insert_trigger_name = "ri_insert_#{self.table_name}_#{@ccount}_#{rf.referent.table_name}"
        delete_trigger_name = "ri_delete_#{self.table_name}_#{@ccount}_#{rf.referent.table_name}"
        
        self.db.execute_batch("CREATE TRIGGER #{insert_trigger_name} BEFORE INSERT ON \"#{self.table_name}\" WHEN new.\"#{cname}\" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM \"#{rf.referent.table_name}\" WHERE new.\"#{cname}\" == \"#{rf.column}\") BEGIN SELECT RAISE(ABORT, 'constraint #{insert_trigger_name} (#{rf.referent.table_name} missing foreign key row) failed'); END;")

        self.db.execute_batch("CREATE TRIGGER #{delete_trigger_name} BEFORE DELETE ON \"#{rf.referent.table_name}\" WHEN EXISTS (SELECT 1 FROM \"#{self.table_name}\" WHERE old.\"#{rf.column}\" == \"#{cname}\") BEGIN DELETE FROM \"#{self.table_name}\" WHERE \"#{cname}\" = old.\"#{rf.column}\"; END;") if rf.options[:on_delete] == :cascade

        @ccount = @ccount + 1
      end
    end
  end
  
  # Declares a constraint.  Only check constraints are supported; see
  # the check method.
  def declare_constraint(cname, kind, *details)
    ensure_accessors
    info = details.join(" ")
    @constraints << "constraint #{cname} #{kind} #{info}"
  end
  
  # Creates a new row in the table with the supplied column values.
  # May throw a SQLite3::SQLException.
  def create(*args)
    new_row = args[0]
    new_row[:created] = new_row[:updated] = SQLBUtil::timestamp
    
    cols = colnames.intersection new_row.keys
    colspec = (cols.map {|col| col.to_s}).join(", ")
    valspec = (cols.map {|col| col.inspect}).join(", ")
    res = nil

    # resolve any references in the args
    new_row.each do |k,v|
      new_row[k] = v.row_id if v.class.ancestors.include? Persisting
    end

    self.db.transaction do |db|
      stmt = "insert into #{table_name} (#{colspec}) values (#{valspec})"
#      p stmt
      db.execute(stmt, new_row)
      res = find(db.last_insert_row_id)
    end
    res
  end
  
  # Returns a string consisting of the DDL statement to create a table
  # corresponding to this class. 
  def table_decl
    cols = columns.join(", ")
    consts = constraints.join(", ")
    if consts.size > 0
      "create table #{table_name} (#{cols}, #{consts});"
    else
      "create table #{table_name} (#{cols});"
    end
  end
  
  # Creates a table in the database corresponding to this class.
  def create_table(dbkey=:default)
    self.db ||= Persistence::dbs[dbkey]
    self.db.execute(table_decl)
    @creation_callbacks.each {|func| func.call}
  end

  def db
    @db || Persistence::db
  end

  def db=(d)
    @db = d
  end

  # Ensure that all the necessary accessors on our class instance are defined 
  # and that all metaclass fields have the appropriate values
  def ensure_accessors
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

  # Returns the number of rows in the table backing this class
  def count
    result = self.db.execute("select count(row_id) from #{table_name}")[0]
    result[0].to_i
  end

  def find_tuple(id)
    res = self.db.execute("select * from #{table_name} where row_id = ?", id)
    if res.size == 0
      nil
    else
      res[0]
    end
  end
end

module Persisting
  def self.included(other)
    class << other
      include PersistingClassMixins
    end

    other.class_eval do
      attr_reader :row_id
      attr_reader :created
      attr_reader :updated
    end
  end
  
  def db
    self.class.db
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
    @created = @tuple["created"]
    @updated = @tuple["updated"]
    resolve_referents
    self.class.dirtied[@row_id] ||= @expired_after
    self
  end
  
  # Deletes the row corresponding to this object from the database; 
  # invalidates =self= and any other objects backed by this row
  def delete
    self.db.execute("delete from #{self.class.table_name} where row_id = ?", @row_id)
    mark_dirty
    @tuple = nil
    @row_id = nil
  end

  ## Begin private methods

  private
  
  # Fetches updated attribute values from the database if necessary
  def freshen
    if needs_refresh?
      @tuple = self.class.find_tuple(@row_id)
      if @tuple
        @updated = @tuple["updated"]
      else
        @row_id = @updated = @created = nil
      end
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
    self.class.dirtied[@row_id] = SQLBUtil::timestamp
  end
  
  # Mark this row as consistent with the underlying database as of now
  def mark_fresh
    @expired_after = SQLBUtil::timestamp
  end
  
  # Helper method to update the row in the database when one of our fields changes
  def update(attr_name, value)
    mark_dirty
    self.db.execute("update #{self.class.table_name} set #{attr_name} = ?, updated = ? where row_id = ?", value, SQLBUtil::timestamp, @row_id)
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

end

end
