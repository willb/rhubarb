# Foreign-key abstraction for Rhubarb.
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
end