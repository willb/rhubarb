# Database interface for Rhubarb
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
  module Persistence
    class DbCollection < Hash
      alias orig_set []=
      
      def []=(key,db)
        setup_db(db) if db
        orig_set(key,db)
      end
      
      private
      def setup_db(db)
        db.results_as_hash = true
        db.type_translation = true
        db.busy_timeout(150)
        class << db
          def stmts
            @rhubarb_stmts ||= {}
            @rhubarb_stmts
          end
        end
      end
    end
    
    @dbs = DbCollection.new
    
    def self.open(filename, which=:default)
      dbs[which] = SQLite3::Database.new(filename)
    end
  
    def self.close(which=:default)
      current_db = dbs[which]
      if current_db
        dbs.delete(which)
        current_db.stmts.values.each {|pstmt| pstmt.close }
        current_db.close
      end
    end
  
    def self.db
      dbs[:default]
    end
    
    def self.db=(d)
      dbs[:default] = d
    end
  
    def self.dbs
      @dbs
    end
  end
end