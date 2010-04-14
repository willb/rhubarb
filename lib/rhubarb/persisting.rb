# Instance mixins for persisting classes.  Part of Rhubarb.
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

module Rhubarb
  
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
    
    def hash
      freshen
      @row_id ^ self.class.table_name.hash
    end
    
    def ==(other)
      freshen
      self.class == other.class && other.row_id == self.row_id
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
      db.do_query("delete from #{self.class.table_name} where row_id = ?", @row_id)
      mark_dirty
      @tuple = nil
      @row_id = nil
    end

    def to_hash
      result = {}
      @tuple.each_pair do |key, value|
        result[key.to_sym] = value unless key.class == Fixnum
      end
      result
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
      self.class.dirtied[@row_id] = Util::timestamp
    end

    # Mark this row as consistent with the underlying database as of now
    def mark_fresh
      @expired_after = Util::timestamp
    end

    # Helper method to update the row in the database when one of our fields changes
    def update(attr_name, value)
      mark_dirty

      db.do_query("update #{self.class.table_name} set #{attr_name} = ?, updated = ? where row_id = ?", value, Util::timestamp, @row_id)
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
