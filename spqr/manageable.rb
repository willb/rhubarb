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
  class ManageableMeta < Struct.new(:classname, :package, :description, :mmethods, :options, :statistics, :properties)
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

    def declare_statistic(name, kind, options)
      declare_basic(:statistic, name, kind, options)
    end

    def declare_property(name, kind, options)
      declare_basic(:property, name, kind, options)
    end

    private
    def declare_basic(what, name, kind, options)
      what_plural = "#{what.to_s.gsub(/y$/, 'ie')}s"
      w_get = what_plural.to_sym
      w_set = "#{what_plural}=".to_sym

      self.send(w_set, (self.send(w_get) or []))

      w_class = "#{what.to_s.capitalize}Meta"
      self.send(w_get) << SPQR.const_get(w_class).new(name, kind, options)
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

      def result.declare(name, kind, direction, description=nil, options=nil)
        options ||= {}
        arg = ::SPQR::ArgMeta.new name, kind, direction, description, options.dup
        self << arg
      end

      result
    end
  end

  class ArgMeta < Struct.new(:name, :kind, :direction, :description, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
    end
  end

  class PropertyMeta < Struct.new(:name, :kind, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
    end
  end

  class StatisticMeta < Struct.new(:name, :kind, :options)
    def initialize(*a)
      super *a
      self.options = (({} unless self.options) or self.options.dup)
    end
  end

  module Manageable
    def qmf_oid
      result = 0
      if self.respond_to? :spqr_object_id 
        result = spqr_object_id
      else
        result = object_id
      end
      
      result & 0x7fffffff
    end

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

      def other.spqr_statistic(name, kind, options=nil)
        spqr_meta.declare_statistic(name, kind, options)

        self.class_eval do
          # XXX: should cons up a "safe_attr_accessor" method that works like this:
          attr_reader name.to_sym unless instance_methods.include? "#{name}"
          attr_writer name.to_sym unless instance_methods.include? "#{name}="
        end
      end
      
      def other.spqr_property(name, kind, options=nil)
        spqr_meta.declare_property(name, kind, options)

        # add a property accessor to instances of other
        self.class_eval do
          attr_reader name.to_sym unless instance_methods.include? "#{name}"
          attr_writer name.to_sym unless instance_methods.include? "#{name}="
        end

        if options and options[:index]
          # if this is an index property, add a find-by method if one
          # does not already exist
          find_by_prop = "find_by_#{name}".to_sym
          unless other.respond_to? find_by_prop
            class << other
              define_method find_by_prop do |arg|
                raise "#{self} must define find_by_#{name}(arg)"
              end
            end
          end
        end
      end

      unless other.respond_to? :find_by_id
        def other.find_by_id(id)
          raise "#{self} must define find_by_id(id)"
        end
      end

      unless other.respond_to? :find_all
        def other.find_all
          raise "#{self} must define find_all"
        end
      end

      unless other.respond_to? :class_id
        def other.class_id
          package_list = spqr_meta.package.to_s.split(".")
          cls = spqr_meta.classname.to_s or self.name.to_s
          ((package_list.map {|pkg| pkg.capitalize} << cls).join("::")).hash & 0x7fffffff
        end
      end

      other.spqr_class other.name.to_sym
    end
  end
end
