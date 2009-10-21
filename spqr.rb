#!/usr/bin/env ruby

# SPQR:  Schema Processor for QMF/Ruby agents
# Generates a skeleton QMF agent application from a schema file.
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


require 'rexml/document'
require 'fileutils'
require 'optparse'

module XmlConstants
  TYPES = {
    'absTime' => 'Qmf::TYPE_ABSTIME',
    'array' => 'Qmf::TYPE_ARRAY',      # XXX:  is this right?
    'bool' => 'Qmf::TYPE_BOOL',
    'deltaTime' => 'Qmf::TYPE_DELTATIME',
    'double' => 'Qmf::TYPE_DOUBLE',
    'float' => 'Qmf::TYPE_FLOAT',
    'int16' => 'Qmf::TYPE_INT16',
    'int32' => 'Qmf::TYPE_INT32',
    'int64' => 'Qmf::TYPE_INT64',
    'int8' => 'Qmf::TYPE_INT8',
    'list' => 'Qmf::TYPE_LIST',        # XXX:  is this right?
    'lstr' => 'Qmf::TYPE_LSTR',
    'map' => 'Qmf::TYPE_MAP',
    'objId' => 'Qmf::TYPE_REF',
    'sstr' => 'Qmf::TYPE_SSTR',
    'uint16' => 'Qmf::TYPE_UINT16',
    'uint32' => 'Qmf::TYPE_UINT32',
    'uint64' => 'Qmf::TYPE_UINT64',
    'uint8' => 'Qmf::TYPE_UINT8',
    'uuid' => 'Qmf::TYPE_UUID'
  }

  ACCESS = {
    "RC" => 'Qmf::ACCESS_READ_CREATE',
    "RW" => 'Qmf::ACCESS_READ_WRITE',
    "RO" => 'Qmf::ACCESS_READ_ONLY',
    "R" => 'Qmf::ACCESS_READ_ONLY'
  }

  DIRECTION = {
    "I" => 'Qmf::DIR_IN',
    "O" => 'Qmf::DIR_OUT',
    "IO" => 'Qmf::DIR_IN_OUT'
  }
end

module PrettyPrinter
  def writemode
    $PP_WRITEMODE ||= File::WRONLY|File::CREAT
  end
  
  def stack
    @fstack ||= [STDOUT]
  end
  
  def inc_indent
    @indent = indent + 2
  end
  
  def dec_indent
    @indent = indent - 2
  end
  
  def indent
    @indent ||= 0
  end
  
  def outfile
    @fstack[-1] or STDOUT
  end
  
  def pp(s)
    outfile.puts "#{' ' * indent}#{s}\n"
  end
  
  def pp_decl(kind, name, etc=nil)
    pp "#{kind} #{name}#{etc}"
    inc_indent
    yield if block_given?
    dec_indent
    pp "end"
  end

  def pp_call(callable, args)
    arg_repr = args.map {|arg| (arg.inspect if arg.kind_of? Hash) or arg}.join(', ')
    pp "#{callable}(#{arg_repr})"
  end
  
  def pp_invoke(receiver, method, args)
    pp_call "#{receiver}.#{method}", args
  end
  
  def with_output_to(filename, &action)
    File::open(filename, writemode) do |of|
      stack << of
      action.call      
      stack.pop
    end
  end
end

module MiscUtil
  def symbolize_dict(k, kz=nil)
    k2 = {}
    kz ||= k.keys
    
    k.keys.each do |key|
      k2[key.to_sym] = k[key] if (kz.include?(key) or kz.include?(key.to_sym))
    end
    
    k2
  end
end

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
    kind = XmlConstants::TYPES[kind] if XmlConstants::TYPES[kind] 
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
      @@p_args_initialized ||= false
      unless @@p_args_initialized
        @@p_args = []

        class << @@p_args
          def declare(name, kind, dir, desc, options)
            opts = options.dup
            kind = ::XmlConstants::TYPES[kind] if ::XmlConstants::TYPES[kind] 
            dir = ::XmlConstants::DIRECTION[dir] if ::XmlConstants::DIRECTION[dir]
            self << ::SchemaClass::SchemaArg.new(name, kind, dir, desc, opts)
          end
        end

        @@p_args_initialized = true
      end
      @@p_args.clone
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
  include PrettyPrinter
  
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
      fqcn = (@package_list.map {|pkg| pkg.capitalize} << @sc.name).join("::")
      pp "\# CLASS_ID is the identifier for all objects of this class; it is combined with an object identifier to uniquely identify QMF objects"
      pp "CLASS_ID = #{fqcn.hash}"
      
      pp '# Find method (NB:  you must implement this)'
      pp_decl :def, "#{@sc.name}.find_by_id", "(objid)" do
        pp "#{@sc.name}.new"
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
      pp "puts 'Requested property #{property.name}'"
      pp "nil"
    end
  end

  def gen_statistic(statistic)
    pp ""
    pp "\# statistic #{statistic.name}"
    pp_decl :def, "#{statistic.name}" do
      pp "puts 'Requested statistic #{statistic.name}'"
      pp "nil"
    end
  end

  def gen_method(method)
    pp ""
    pp "\# #{method.name} #{method.desc}"
    method.args.each do |arg|
      pp "\# * #{arg.name} (#{arg.kind}/#{arg.dir})"
      pp "\# #{arg.desc}"
    end
    
    pp_decl :def, method.name, "(args)" do
      in_params = method.args.select {|arg| arg.dir == 'Qmf::DIR_IN'}
      out_params = method.args.select {|arg| arg.dir == 'Qmf::DIR_OUT'}
      inout_params = method.args.select {|arg| arg.dir == 'Qmf::DIR_IN_OUT'}
      
      if in_params.size + inout_params.size > 0  
        what = "in"
        
        if in_params.size > 0 and inout_params.size > 0
          what << " and in/out"
        elsif inout_params.size > 0
          what << "/out"
        end
          
        pp "\# Print values of #{what} parameters"
        (in_params + inout_params).each do |arg|
          pp 'puts "' + "#{arg.name} => " + '#{args[' + arg.name.to_sym.inspect + ']}"' + " \# #{}"
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
          pp "args[#{arg.name.to_sym.inspect}] = args[#{arg.name.to_sym.inspect}]"
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
    
    cc = "klasses"
    
    with_output_to @fn do
      pp_decl :class, "App", " < Qmf::AgentHandler" do

        pp_decl :def, "App.schema_classes" do
          pp "@schema_classes ||= reconstitute_classes"
        end

        pp_decl :def, "App.reconstitute_classes" do
          pp "#{cc} = []"
          @scs.each do |sc|
            klazzname = "klazz_#{sc.name}"
            pp "#{klazzname} = Qmf::SchemaObjectClass.new(#{sc.package.inspect}, #{sc.name.inspect})"
            sc.with_each :properties do |prop|
              pp "#{klazzname}.add_property(Qmf::SchemaProperty.new(#{prop.name.inspect}, #{prop.kind}, #{prop.options.inspect}))"
            end
    
            sc.with_each :statistics do |stat|
              pp "#{klazzname}.add_statistic(Qmf::SchemaStatistic.new(#{stat.name.inspect}, #{stat.kind}, #{stat.options.inspect}))"
            end
            
            sc.with_each :methods do |mth|
              methodname = "#{klazzname}_#{mth.name}"
              pp "#{methodname} = Qmf::SchemaMethod.new(#{mth.name.inspect}, #{mth.options.inspect})"
              
              mth.args.each do |arg|
                pp "#{methodname}.add_argument(Qmf::SchemaArgument.new(#{arg.name.inspect}, #{arg.kind}, #{arg.options.inspect}))"
              end
              
              pp "#{klazzname}.add_method(#{methodname})"
              pp ""
              pp "#{cc} << #{klazzname}"
              pp ""
            end
            
            pp "#{cc}"
          end
        end

        pp "private_class_method :reconstitute_classes"
        
      end
    end
  end  
end

class SupportGenerator
  
  def gen
smod <<END
def get_query(context, query, userId)
  puts "Query: user=#{userId} context=#{context} class=#{query.class_name} object_num=#{query.object_id.object_num_low if query.object_id}"
  if query.class_name == 'parent'
      @agent.query_response(context, @parent)
  end
  @agent.query_complete(context)
end

def method_call(context, name, object_id, args, userId)
  puts "Method: user=#{userId} context=#{context} method=#{name} object_num=#{object_id.object_num_low if object_id} args=#{args} (#{args.inspect})"
  oid = @agent.alloc_object_id(2)
  args['result'] = "Hello, #{args['name']}!"
  @agent.method_response(context, 0, "OK", args)
end
END
  smod
  end
end

class QmfSchemaProcessor
  include MiscUtil
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

def main
  $WRITEMODE
  $OUTDIR = "."
  
  op = OptionParser.new do |opts|
    opts.banner = "Usage spqr.rb [options] schema-file"
    
    opts.on("-n", "--noclobber", "don't overwrite pre-existing output files") do |noclob|
      $PP_WRITEMODE = File::WRONLY|File::EXCL|File::CREAT
    end
    
    opts.on("-d", "--output-dir DIR", "directory in which to place generated app and controllers") do |dir|
      $OUTDIR = dir
    end
  end
  
  begin
    op.parse!
  rescue OptionParser::InvalidOption
    puts op
    exit
  end
    

  begin
    QmfSchemaProcessor.new(ARGV[0]).main
  rescue SystemCallError => sce
    if sce.errno == Errno::EEXIST::Errno
      fn = sce.message.split(" ")[-1] # XXX:  won't work for filenames with spaces
      puts "Not overwriting #{fn}; don't use --noclobber if you don't want this behavior"
    elsif sce.errno == Errno::ENOENT::Errno
      fn = sce.message.split(" ")[-1] # XXX:  won't work for filenames with spaces
      puts "File or directory \"#{fn}\" not found"
      puts sce.backtrace
    else
      puts "Failed due to #{sce.inspect}"
    end
  end
end

main