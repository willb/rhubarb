# SPQR:  Schema Processor for QMF/Ruby agents
#
# Managed object mixin.
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

module SPQR
  class BlankSlate
    instance_methods.each do |m|
      undef_method m unless m.to_s =~ /^__|freeze|method_missing|respond_to?|initialize/
    end
  end

  class ManageableMeta < BlankSlate
    attr_accessor :name, :package, :description, :methods, :options

    def initialize
      @methods = []
    end
    
    def declare_method(name, desc, options) 
      result = MethodMeta.new name, desc, options
      yield result.args if block_given?
      @methods << result
      @methods[-1]
    end
  end

  class MethodMeta < BlankSlate
    attr_accessor :name, :description, :args, :options
    def initialize(n, d, opts=nil)
      name = n
      description = d
      args = gen_args
      options = (opts.dup if opts) or {}
    end

    private
    def gen_args
      result = []

      def result.declare(name, type, direction, options=nil)
        arg = ::SPQR::ArgMeta.new name, type, direction, options
        self << arg
      end

      result
    end
  end

  class ArgMeta < BlankSlate
    attr_accessor :name, :type, :description, :options

    def initialize(n,t,d,opts)
      name = n
      type = t
      description = d
      options = (opts.dup if opts) or {}
    end
  end

  module Manageable

    def self.included(other)
      def other.spqr_meta
        @spqr_meta ||= ::SPQR::ManageableMeta.new
     end

      # Exposes a method to QMF
      def other.expose(name, description=nil, options=nil, &argblock)
        spqr_meta.declare_method(name, description, options) &argblock
      end      
    end
  end
end
