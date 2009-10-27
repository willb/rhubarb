# SPQR:  Schema Processor for QMF/Ruby agents
#
# Application skeleton class
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

require 'spqr'
require 'qmf'
require 'logger'

module SPQR
  def manageable?(k)
    k.is_a? Class and k.included_modules.include? ::SPQR::Manageable
  end

  class App < Qmf::AgentHandler
    def initialize(options=nil)
      options ||= {}
      logfile = options[:logfile] or STDERR
      loglevel = options[:loglevel] or Logger::WARN

      @log = Logger.new(logfile)
      @log.level = loglevel

      @object_classes = []
      @schema_classes = []
    end

    def register(*ks)
      manageable_ks = ks.select {|kl| manageable? kl}
      unmanageable_ks = ks.select {|kl| not manageable? kl}
      manageable_ks.each do |klass|
        @object_classes << klass
        @schema_classes << schematize klass
      end
      
      unmanageable_ks.each do |klass|
        @log.warn("SPQR can't manage #{klass}, which was registered")
      end
    end

    private
    def schematize(klass)
      meta = klass.spqr_meta
      package = meta.package.to_s
      classname = meta.classname.to_s

      sc = Qmf::SchemaObjectClass.new(package, classname)
      
      meta.mmethods.each do |mm|
        m_opts = mm.options
        m_opts[:desc] ||= mm.description
        
        method = Qmf::SchemaMethod.new(mm.name.to_s, mm.package.to_s, m_opts)
        
        mm.args.each do |arg| 
          arg_opts = arg.options
          arg_opts[:desc] ||= arg.description
          arg_name = arg.name.to_s 
          arg_type = get_xml_constant(arg.kind.to_s, ::SPQR::XmlConstants::TYPES)
          arg_dir = get_xml_constant(arg.direction.to_s, ::SPQR::XmlConstants::DIRECTION)
        end

      end

      sc
    end
    
    def get_xml_constant(xml_key, dictionary)
      string_val = dictionary[xml_key]
      return xml_key unless string_val

      actual_val = const_lookup(string_val)
      return string_val unless actual_val

      return actual_val
    end

    # turns a string name of a constant into the value of that
    # constant; returns that value, or nil if fqcn doesn't correspond
    # to a valid constant
    def const_lookup(fqcn)
      hierarchy = fqcn.split("::")
      const = hierarchy.pop
      mod = Kernel
      hierarchy.each do |m|
        mod = mod.const_get(m)
      end
      mod.const_get(const) rescue nil
    end
  end
end
