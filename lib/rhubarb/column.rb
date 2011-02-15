# Column abstraction for Rhubarb.
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
        "'#@name' #@kind"
      else
        "'#@name' #@kind #{qualifiers}"
      end
    end
  end
end