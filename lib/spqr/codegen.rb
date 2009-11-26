# Code generation for SPQR
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

require 'rexml/document'
require 'fileutils'
require 'optparse'

module SPQR

  class SchemaClass
    attr_accessor :name, :package

    def self.declare(name, package)
      kl = SchemaClass.new(name, package)
      yield kl if block_given?
      kl
    end

    def declare_property(name, kind, options)
      declare_basic(:property, name, kind, options)
    end

    def declare_statistic(name, kind, options)
      declare_basic(:statistic, name, kind, options)
    end

    def declare_method(name, desc, options)
      result = SchemaMethod.new name, desc, options.dup

      yield result.args if block_given?
      @methods << result
      @methods[-1]
    end

    def initialize(nm=nil, pkg=nil)
      @name, @package = nm, pkg
      @properties = []
      @statistics = []
      @methods = []
    end

    def with_each(what)
      source = self.instance_variable_get("@#{what}".to_sym) || []
      source.each do |x|
        yield x if block_given?
      end
    end

    def member_count(what)
      source = self.instance_variable_get("@#{what}".to_sym) || []
      source.size
    end

    private
    def declare_basic(what, name, kind, options)
      @wherelocs ||= {:property=>@properties,:statistic=>@statistics}
      where = @wherelocs[what]

      opts = options.dup
      opts[:index] = true if opts[:index]
      desc = opts.delete(:desc)

      where << SchemaBasic.new(what, name, desc, kind, opts)
      where[-1]
    end

    class SchemaBasic
      attr_accessor :name, :kind, :desc, :options
      def initialize(what,nm,desc,knd,opts)
        @what = what
        @name = nm
        @kind = knd
        @options = opts
        @desc = desc.gsub(/\s+/, " ") if desc
      end

      def property?
        @what == :property
      end

      def statistic?
        @what == :statistic
      end
    end

    class SchemaMethod
      attr_accessor :name, :desc, :options, :args
      def initialize(nm,desc,opts=nil)
        @options = (opts && opts.dup) || {}
        @name = nm
        @desc = desc.gsub(/\s+/, " ") if desc
        @args = arg_struct
      end

      private
      def arg_struct
        @@prototype_args ||= gen_prototype_args
        @@prototype_args.clone
      end

      def gen_prototype_args
        prototype_args = []

        def prototype_args.declare(name, kind, dir, desc, options)
          opts = options.dup

          self << ::SPQR::SchemaClass::SchemaArg.new(name, kind, dir, desc, opts)
        end

        prototype_args
      end
    end

    class SchemaArg
      attr_accessor :name, :desc, :kind, :dir, :options
      def initialize(nm, knd, dr, dsc, opts)
        @name = nm
        @desc = dsc.gsub(/\s+/, " ") if dsc
        @kind = knd
        @dir = dr
        @options = opts
      end

      def inspect
        [:name, :desc, :kind, :dir, :options].map { |sel|"[#{sel}:#{self.send(sel)}]" }.join(" ")
      end
    end
  end


  class ModelClassGenerator
    include ::SPQR::PrettyPrinter

    def ModelClassGenerator.id_registry
      @id_registry ||= {}
    end

    def ModelClassGenerator.class_registry
      @class_registry ||= {}
    end

    def initialize(sc)
      @sc = sc
    end

    def gen
      @package_list = @sc.package.split(".")
      package_dir = "./#{@package_list.join('/')}"
      FileUtils.mkdir_p package_dir

      filename = "#{$OUTDIR}/#{package_dir}/#{@sc.name}.rb"
      with_output_to filename do
        gen_class
      end
    end

    private
    def gen_class
      @package_list.map {|pkg| pkg.capitalize}.each do |modname|
        pp "module #{modname}"
        inc_indent
      end

      pp_decl :class, @sc.name do
        pkgname = (@package_list.map {|pkg| pkg.capitalize}).join("::")
        fqcn = ("#{pkgname}::#{@sc.name}" if pkgname) or @sc.name

        pp "include SPQR::Manageable"
        pp ""

        pp "spqr_package '#{@package_list.join(".")}'"
        pp "spqr_class '#{@sc.name.split("::")[-1]}'"

        pp '# Find method (NB:  you must implement this)'
        pp_decl :def, "#{@sc.name}.find_by_id", "(objid)" do
          pp "#{@sc.name}.new"
        end

        pp "\n# Find-all method (NB:  you must implement this)"
        pp_decl :def, "#{@sc.name}.find_all" do
          pp "[#{@sc.name}.new]"
        end

        ModelClassGenerator.id_registry[fqcn.hash] = fqcn
        ModelClassGenerator.class_registry[fqcn] = fqcn.hash

        pp "\#\#\# Property method declarations" if @sc.member_count(:properties) > 0
        @sc.with_each :properties do |property|
          gen_property property
        end

        pp "\#\#\# Statistic method declarations" if @sc.member_count(:statistics) > 0
        @sc.with_each :statistics do |statistic|
          gen_statistic statistic
        end

        pp "\#\#\# Schema method declarations"
        @sc.with_each :methods do |method|
          gen_method method
        end
      end

      @package_list.size.times do
        dec_indent
        pp "end"
      end
    end

    def gen_property(property)
      pp ""
      pp "\# property #{property.name} #{property.kind} #{property.desc}"
      pp_decl :def, "#{property.name}" do
        pp "log.debug 'Requested property #{property.name}'"
        pp "nil"
      end

      pp ""
      pp_decl :def, "#{property.name}=", "(val)" do
        pp "log.debug 'Set property #{property.name} to \#\{val\}'"
        pp "nil"
      end
      
      property.options[:desc] = property.desc if property.desc

      pp ""
      pp "spqr_property #{property.name.to_sym.inspect}, #{property.kind.to_sym.inspect}, #{property.options.inspect.gsub(/[{}]/, '')}"
    end

    def gen_statistic(statistic)
      pp ""
      pp "\# statistic #{statistic.name}"
      pp_decl :def, "#{statistic.name}" do
        pp "log.debug 'Requested statistic #{statistic.name}'"
        pp "nil"
      end
      
      statistic.options[:desc] = statistic.desc if statistic.desc
      
      pp ""
      pp "spqr_property #{statistic.name.to_sym.inspect}, #{statistic.kind.to_sym.inspect}, #{statistic.options.inspect.gsub(/[{}]/, '')}"
    end

    def gen_method(method)
      pp ""
      pp "\# #{method.name} #{method.desc}"
      method.args.each do |arg|
        pp "\# * #{arg.name} (#{arg.kind}/#{arg.dir})"
        pp "\# #{arg.desc}"
      end
      
      in_params = method.args.select {|arg| ['in', 'i', 'qmf::dir_in'].include? arg.dir.to_s.downcase }
      out_params = method.args.select {|arg| ['out', 'o', 'qmf::dir_out'].include? arg.dir.to_s.downcase }
      inout_params = method.args.select {|arg| ['inout', 'io', 'qmf::dir_inout'].include? arg.dir.to_s.downcase }
      
      pp_decl :def, method.name, "(args)" do
        
        if in_params.size + inout_params.size > 0  
          what = "in"
          
          if in_params.size > 0 and inout_params.size > 0
            what << " and in/out"
          elsif inout_params.size > 0
            what << "/out"
          end
          
          pp "\# Print values of #{what} parameters"
          (in_params + inout_params).each do |arg|
            argdisplay = arg.name.to_s.inspect
            pp('log.debug "' + "#{arg.name} => " + '#{args[' + "#{argdisplay}" + ']}"' + " \# #{}")
          end
        end

        if out_params.size + inout_params.size > 0
          what = "out"

          if out_params.size > 0 and inout_params.size > 0
            what << " and in/out"
          elsif inout_params.size > 0
            what = "in/out"
          end

          pp "\# Assign values to #{what} parameters"

          (out_params + inout_params).each do |arg|
            argdisplay = arg.name.to_s.inspect
            pp "args[#{argdisplay}] = args[#{argdisplay}]"
          end
        end
      end


      pp ""
      pp_decl :spqr_expose, "#{method.name.to_sym.inspect} do |args|" do
        {:in => in_params, :inout => inout_params, :out => out_params}.each do |dir,coll|
          coll.each do |arg|
            arg_nm = arg.name
            arg_kd = arg.kind
            arg_opts = arg.options.inspect.gsub(/^[{](.+)[}]$/, '\1')
            pp "args.declare :#{arg_nm}, :#{arg_kd}, :#{dir}, #{arg_opts}"
          end
        end
      end
    end
  end

  class AppBoilerplateGenerator
    include PrettyPrinter

    # scs is a list of schemaclass objects, fn is an output filename
    def initialize(scs, fn)
      @scs = scs
      @fn = fn
    end

    # cc is the name of the variable that will hold a collection of schema classes
    def gen
      with_output_to @fn do
        pp "require 'rubygems'"
        pp "require 'spqr/spqr'"
        pp "require 'spqr/app'"

        pp ""

        @scs.each do |sc|
          pp("require '#{sc.package.gsub(/[.]/, '/')}/#{sc.name}'")
        end

        
        pp ""
        
        pp "app = SPQR::App.new(:loglevel => :debug)"
        
        klass_list = @scs.collect do |sc|
          (sc.package.split(".").collect{|pkg| pkg.capitalize} << sc.name).join("::")
        end
        
        pp "app.register #{klass_list.join ','}"
        
        pp ""

        pp "app.main"
      end
    end  
  end

  class QmfSchemaProcessor
    include ::SPQR::MiscUtil
    def initialize(fn)
      @package = nil
      @file = fn
      @doc = nil
      @indent = 0
      @schema_classes = []
    end

    def main
      File::open(@file, "r") {|infile| @doc = REXML::Document.new(infile)}

      process_schema
      @schema_classes.each do |klass|
        ModelClassGenerator.new(klass).gen
      end

      AppBoilerplateGenerator.new(@schema_classes, "#{$OUTDIR}/agent-app.rb").gen
    end

    private

    def process_schema
      @package = @doc.root.attributes["package"]
      @package_list = @package.split(".")

      @package_dir = "#{$OUTDIR}/#{@package_list.join('/')}"

      FileUtils.mkdir_p @package_dir

      REXML::XPath.each(@doc.root, "/schema/class") do |elt|
        @schema_classes << process_class(elt)
      end
    end

    def process_class(elt)
      classname = "#{elt.attributes['name']}"

      SchemaClass.declare classname, @package do |klass|      
        REXML::XPath.each(elt, "property") do |property|
          name = property.attributes['name']
          kind = property.attributes['type']
          opts = symbolize_dict(property.attributes, [:desc, :index, :access, :optional, :min, :max, :maxlen, :unit])
          opts[:index] = (opts[:index].to_s == '1' or opts[:index].to_s.downcase == 'y')
          klass.declare_property name, kind, opts
        end

        REXML::XPath.each(elt, "statistic") do |statistic|
          name = statistic.attributes['name']
          kind = statistic.attributes['type']
          opts = symbolize_dict(statistic.attributes, [:desc, :unit])
          klass.declare_statistic name, kind, {}
        end

        REXML::XPath.each(elt, "method") do |method|
          name = method.attributes['name']
          desc = method.attributes['desc']
          klass.declare_method name, desc, {} do |args|
            REXML::XPath.each(method, "arg") do |arg|
              opts = symbolize_dict(arg.attributes, [:name, :type, :refPackage, :refClass, :dir, :unit, :min, :max, :maxlen, :desc, :default, :references])
              name = opts.delete(:name)
              kind = opts.delete(:type)
              dir = opts.delete(:dir)
              desc = opts.delete(:desc)
              args.declare(name, kind, dir, desc, opts)
            end
          end
        end

        klass
      end
    end
  end
end
