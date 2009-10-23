# SPQR:  Schema Processor for QMF/Ruby agents
#
# Manageable object mixin and support classes.
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
  class ManageableMeta < Struct.new(:classname, :package, :description, :mmethods, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
    end

    def declare_method(name, desc, options, blk=nil)
      self.mmethods ||= []
      result = MethodMeta.new name, desc, options
      blk.call(result.args) if blk
      self.mmethods << result
      self.mmethods[-1]
    end
  end

  class MethodMeta < Struct.new(:name, :description, :args, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
      self.args = gen_args
    end

    private
    def gen_args
      result = []

      def result.declare(name, type, direction, options=nil)
        options ||= {}
        arg = ::SPQR::ArgMeta.new name, type, direction, options.dup
        self << arg
      end

      result
    end
  end

  class ArgMeta < Struct.new(:name, :type, :description, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
    end
  end

  module Manageable

    def self.included(other)
      def other.spqr_meta
        @spqr_meta ||= ::SPQR::ManageableMeta.new
      end

      # Exposes a method to QMF
      def other.spqr_expose(name, description=nil, options=nil, &blk)
        spqr_meta.declare_method(name, description, options, blk)
      end      

      def other.spqr_package(nm)
        spqr_meta.package = nm
      end

      def other.spqr_class(nm)
        spqr_meta.classname = nm
      end

      def other.spqr_description(d)
        spqr_meta.description = d
      end

      def other.spqr_options(opts)
        spqr_meta.options = opts.dup
      end      
      
    end
  end
end
