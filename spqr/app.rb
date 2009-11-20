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

require 'spqr/spqr'
require 'qmf'
require 'logger'

module SPQR
  class App < Qmf::AgentHandler
    class ClassMeta < Struct.new(:object_class, :schema_class) ; end

    def initialize(options=nil)
      defaults = {:logfile=>STDERR, :loglevel=>Logger::WARN}
      
      # convenient shorthands for log levels
      loglevels = {:debug => Logger::DEBUG, :info => Logger::INFO, :warn => Logger::WARN, :error => Logger::ERROR, :fatal => Logger::FATAL}
        
      options = defaults unless options

      # set unsupplied options to defaults
      defaults.each do |k,v|
        options[k] = v unless options[k]
      end

      # fix up shorthands
      options[:loglevel] = loglevels[options[:loglevel]] if loglevels[options[:loglevel]]

      @log = Logger.new(options[:logfile])
      @log.level = options[:loglevel]

      @log.info("initializing SPQR app....")

      @classes_by_name = {}
      @classes_by_id = {}
    end

    def register(*ks)
      manageable_ks = ks.select {|kl| manageable? kl}
      unmanageable_ks = ks.select {|kl| not manageable? kl}
      manageable_ks.each do |klass|
        @log.info("SPQR will manage registered class #{klass}...")
        
        schemaclass = schematize(klass)

        @classes_by_id[klass.class_id] = klass
        @classes_by_name[klass.name] = ClassMeta.new(klass, schemaclass)
      end
      
      unmanageable_ks.each do |klass|
        @log.warn("SPQR can't manage #{klass}, which was registered")
      end
    end


    def method_call(context, name, obj_id, args, user_id)
      begin
        class_id = obj_id.object_num_high
        obj_id = obj_id.object_num_low

        @log.debug "calling method: context=#{context} method=#{name} object_id=#{obj_id}, args=#{args}, user=#{user_id}"

        # Turn the Qmf::Arguments structure into a proper ruby hash

        # XXX: consider adding appropriate impl method to Manageable
        # to avoid this little dance
        hash_args = qmf_arguments_to_hash(args)

        managed_object = find_object(context, class_id, obj_id)
        @log.debug("managed object is #{managed_object}")

        @log.debug("managed_object.respond_to? #{name.to_sym} ==> #{managed_object.respond_to? name.to_sym}")
        managed_object.send(name.to_sym, hash_args)
        
        # Copy any out parameters from hash_args from the
        # Qmf::Arguments structure; see XXX above
        hash_args.each do |k,v|
          args[k] = (encode_object(v) if v.kind_of?(::SPQR::Manageable)) or v
        end

        @agent.method_response(context, 0, "OK", args)
      rescue Exception => ex
        @log.error "Error calling #{name}: #{ex}"
        @log.error "    " + ex.backtrace.join("\n    ")
        @agent.method_response(context, 1, "ERROR: #{ex}", args)
      end
    end

    def get_query(context, query, user_id)
      @log.debug "query: user=#{user_id} context=#{context} class=#{query.class_name} object_num=#{query.object_id.object_num_low if query.object_id} details=#{query}"

      cmeta = @classes_by_name[query.class_name]
      objs = []
      
      # XXX:  are these cases mutually exclusive?
      
      # handle queries for a certain class
      if cmeta
        objs = objs + cmeta.object_class.find_all.collect {|obj| qmfify(obj)}
      end

      # handle queries for a specific object
      o = find_object(context, query.object_id.object_num_high, query.object_id.object_num_low) rescue nil
      if o
        objs << qmfify(o)
      end

      objs.each do |obj| 
        @log.debug("query_response of: #{obj.inspect}")
        @agent.query_response(context, obj) rescue @log.error($!.inspect)
      end
      
      @log.debug("completing query....")
      @agent.query_complete(context)
    end

    def main
      # XXX:  fix and parameterize as necessary
      @log.debug("starting SPQR::App.main...")
      
      settings = Qmf::ConnectionSettings.new
      settings.host = 'localhost'
      
      @connection = Qmf::Connection.new(settings)
      @log.debug(" +-- @connection created:  #{@connection}")

      @agent = Qmf::Agent.new(self)
      @log.debug(" +-- @agent created:  #{@agent}")

      @agent.set_connection(@connection)
      @log.debug(" +-- @agent.set_connection called")

      @log.debug(" +-- registering classes...")
      @classes_by_name.values.each do |km| 
        @agent.register_class(km.schema_class) 
        @log.debug(" +--+-- #{km.object_class.name} registered")
      end
      
      @log.debug("entering orbit....")
      sleep
    end

    private
    
    def qmf_arguments_to_hash(args)
      result = {}
      args.each do |k,v|
        result[k] = v
      end
      result
    end

    def encode_object(o)
      @agent.alloc_object_id(*(o.qmf_id))
    end

    def find_object(ctx, c_id, obj_id)
      # XXX:  context is currently ignored
      klass = @classes_by_id[c_id]
      klass.find_by_id(obj_id) if klass
    end
    
    def schematize(klass)
      @log.info("Making a QMF schema for #{klass}")

      meta = klass.spqr_meta
      package = meta.package.to_s
      classname = meta.classname.to_s

      sc = Qmf::SchemaObjectClass.new(package, classname)
      
      meta.mmethods.each do |mm|
        @log.info("+-- creating a QMF schema for method #{mm}")
        m_opts = mm.options
        m_opts[:desc] ||= mm.description if mm.description
        
        method = Qmf::SchemaMethod.new(mm.name.to_s, m_opts)
        
        mm.args.each do |arg| 
          @log.info("| +-- creating a QMF schema for arg #{arg}")
          
          arg_opts = arg.options
          arg_opts[:desc] ||= arg.description if (arg.description and arg.description.is_a? String)
          arg_opts[:dir] ||= get_xml_constant(arg.direction.to_s, ::SPQR::XmlConstants::Direction)
          arg_name = arg.name.to_s
          arg_type = get_xml_constant(arg.kind.to_s, ::SPQR::XmlConstants::Type)
          
          if @log.level <= Logger::DEBUG
            local_variables.grep(/^arg_/).each do |local|
              @log.debug("      #{local} --> #{(eval local).inspect}")
            end
          end

          method.add_argument(Qmf::SchemaArgument.new(arg_name, arg_type, arg_opts))
        end

        sc.add_method(method)
      end

      add_attributes(sc, meta.properties, :add_property, Qmf::SchemaProperty)
      add_attributes(sc, meta.statistics, :add_statistic, Qmf::SchemaStatistic)

      sc
    end
    
    def add_attributes(sc, collection, msg, klass, what=nil)
      what ||= (msg.to_s.split("_").pop rescue "property or statistic")
      collection.each do |basic|
        basic_name = basic.name.to_s
        basic_type = get_xml_constant(basic.kind.to_s, ::SPQR::XmlConstants::Type)
        @log.debug("+-- creating a QMF schema for #{what} #{basic_name} (#{basic_type}) with options #{basic.options.inspect}")
        sc.send(msg, klass.new(basic_name, basic_type, basic.options))
      end
    end

    def manageable?(k)
      # FIXME:  move out of App, into Manageable or a related utils module?
      k.is_a? Class and k.included_modules.include? ::SPQR::Manageable
    end

    def get_xml_constant(xml_key, dictionary)
      # FIXME:  move out of App, into a utils module?
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
      # FIXME:  move out of App, into a utils module?
      hierarchy = fqcn.split("::")
      const = hierarchy.pop
      mod = Kernel
      hierarchy.each do |m|
        mod = mod.const_get(m)
      end
      mod.const_get(const) rescue nil
    end

    # turns an instance of a managed object into a QmfObject
    def qmfify(obj)
      @log.debug("trying to qmfify #{obj}:  qmf_oid is #{obj.qmf_oid} and class_id is #{obj.class.class_id}")
      cm = @classes_by_name[obj.class.name]
      return nil unless cm

      qmfobj = Qmf::AgentObject.new(cm.schema_class)

      set_attrs(qmfobj, obj)

      @log.debug("calling alloc_object_id(#{obj.qmf_oid}, #{obj.class.class_id})")
      oid = @agent.alloc_object_id(obj.qmf_oid, obj.class.class_id)
      
      @log.debug("calling qmfobj.set_object_id(#{oid})")
      qmfobj.set_object_id(oid)
      
      @log.debug("returning from qmfify")
      qmfobj
    end

    def set_attrs(qo, o)
      return unless o.class.respond_to? :spqr_meta
      
      attrs = o.class.spqr_meta.properties + o.class.spqr_meta.statistics

      attrs.each do |a|
        getter = a.name.to_s
        @log.debug("setting property/statistic #{getter} to its value from #{o}: #{o.send(getter) if o.respond_to?(getter)}")
        value = o.send(getter) if o.respond_to?(getter)
        if value
          # XXX: remove this line when/if Manageable includes an
          # appropriate impl method
          value = encode_object(value) if value.kind_of?(::SPQR::Manageable)
          qo[getter] = value
        end
      end
    end
  end
end
