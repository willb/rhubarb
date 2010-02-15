# Class mixins for persisting classes.  Part of Rhubarb.
#
# Copyright (c) 2009--2010 Red Hat, Inc.
#
# Author:  William Benton (willb@redhat.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

require 'rhubarb/mixins/freshness'

module Rhubarb
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
    
    alias table_name= declare_table_name

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
      tup ? self.new(tup) : nil
    end
    
    alias find_by_id find

    def find_by(arg_hash)
      arg_hash = arg_hash.dup
      valid_cols = self.colnames.intersection arg_hash.keys
      select_criteria = valid_cols.map {|col| "#{col.to_s} = #{col.inspect}"}.join(" AND ")
      arg_hash.each {|k,v| arg_hash[k] = v.row_id if v.respond_to? :row_id}

      self.db.execute("select * from #{table_name} where #{select_criteria} order by row_id", arg_hash).map {|tup| self.new(tup) }
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
      declare_custom_query(name, "select * from __TABLE__ where #{query}")
    end

    # Declares a custom query method named +name+, and adds it to this class.  The custom query method returns a list of objects corresponding to the rows returned by executing +query+ on the database.  +query+ should select all fields (with +SELECT *+).  If +query+ includes the string +\_\_TABLE\_\_+, it will be expanded to the table name.  Typically, you will want to use +declare\_query+ instead; this method is most useful for self-joins.
    def declare_custom_query(name, query)
      klass = (class << self; self end)
      klass.class_eval do
        define_method name.to_s do |*args|
          # handle reference parameters
          args = args.map {|arg| Util::rhubarb_fk_identity(arg)}

          res = self.db.execute(query.gsub("__TABLE__", "#{self.table_name}"), args)
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
      find_query = "select * from #{table_name} where #{cname} = ?"

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
          res = self.db.execute(find_query, arg)
          res.map {|row| self.new(row)}
        end

        define_method find_first_method_name do |arg|
          res = self.db.get_first_row(find_query, arg)
          res ? self.new(res) : nil
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
        
        rtable = rf.referent.table_name

        self.creation_callbacks << Proc.new do   
          @ccount ||= 0

          insert_trigger_name, delete_trigger_name = %w{insert delete}.map {|op| "ri_#{op}_#{self.table_name}_#{@ccount}_#{rtable}" } 

          self.db.execute_batch("CREATE TRIGGER #{insert_trigger_name} BEFORE INSERT ON \"#{self.table_name}\" WHEN new.\"#{cname}\" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM \"#{rtable}\" WHERE new.\"#{cname}\" == \"#{rf.column}\") BEGIN SELECT RAISE(ABORT, 'constraint #{insert_trigger_name} (#{rtable} missing foreign key row) failed'); END;")

          self.db.execute_batch("CREATE TRIGGER #{delete_trigger_name} BEFORE DELETE ON \"#{rtable}\" WHEN EXISTS (SELECT 1 FROM \"#{self.table_name}\" WHERE old.\"#{rf.column}\" == \"#{cname}\") BEGIN DELETE FROM \"#{self.table_name}\" WHERE \"#{cname}\" = old.\"#{rf.column}\"; END;") if rf.options[:on_delete] == :cascade

          @ccount = @ccount + 1
        end
      end
    end

    # Declares a constraint.  Only check constraints are supported; see
    # the check method.
    def declare_constraint(cname, kind, *details)
      ensure_accessors
      @constraints << "constraint #{cname} #{kind} #{details.join(" ")}"
    end

    # Creates a new row in the table with the supplied column values.
    # May throw a SQLite3::SQLException.
    def create(*args)
      new_row = args[0]
      new_row[:created] = new_row[:updated] = Util::timestamp

      cols = colnames.intersection new_row.keys
      colspec, valspec = [:to_s, :inspect].map {|msg| (cols.map {|col| col.send(msg)}).join(", ")}
      res = nil

      # resolve any references in the args
      new_row.each do |column,value|
        new_row[column] = Util::rhubarb_fk_identity(value)
      end

      stmt = "insert into #{table_name} (#{colspec}) values (#{valspec})"
      db.execute(stmt, new_row)
      res = find(db.last_insert_row_id)
      
      res
    end

    # Returns a string consisting of the DDL statement to create a table
    # corresponding to this class. 
    def table_decl
      ddlspecs = [columns.join(", "), constraints.join(", ")].reject {|str| str.size==0}.join(", ")
      "create table #{table_name} (#{ddlspecs});"
    end

    # Creates a table in the database corresponding to this class.
    def create_table(dbkey=:default)
      self.db ||= Persistence::dbs[dbkey] unless @explicitdb
      self.db.execute(table_decl)
      @creation_callbacks.each {|func| func.call}
    end

    def db
      @db || Persistence::db
    end

    def db=(dbo)
      @explicitdb = true
      @db = dbo
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
      self.db.get_first_value("select count(row_id) from #{table_name}").to_i
    end

    def find_tuple(id)
      self.db.get_first_row("select * from #{table_name} where row_id = ?", id)
    end
    
    include FindFreshest
    
  end
end