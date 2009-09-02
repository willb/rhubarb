#!/usr/bin/env ruby

require 'rexml/document'
require 'FileUtils'

module XmlConstants
  TYPES = {
    'absTime' => Qmf::TYPE_ABSTIME,
    'array' => Qmf::TYPE_ARRAY,      # XXX:  is this right?
    'bool' => Qmf::TYPE_BOOL,
    'deltaTime' => Qmf::TYPE_DELTATIME,
    'double' => Qmf::TYPE_DOUBLE,
    'float' => Qmf::TYPE_FLOAT,
    'int16' => Qmf::TYPE_INT16,
    'int32' => Qmf::TYPE_INT32,
    'int64' => Qmf::TYPE_INT64,
    'int8' => Qmf::TYPE_INT8,
    'list' => Qmf::TYPE_LIST,        # XXX:  is this right?
    'lstr' => Qmf::TYPE_LSTR,
    'map' => Qmf::TYPE_MAP,
    'objId' => Qmf::TYPE_REF,
    'sstr' => Qmf::TYPE_SSTR,
    'uint16' => Qmf::TYPE_UINT16,
    'uint32' => Qmf::TYPE_UINT32,
    'uint64' => Qmf::TYPE_UINT64,
    'uint8' => Qmf::TYPE_UINT8,
    'uuid' => Qmf::TYPE_UUID
  }

  ACCESS = {
    "RC" => Qmf::ACCESS_READ_CREATE,
    "RW" => Qmf::ACCESS_READ_WRITE,
    "RO" => Qmf::ACCESS_READ_ONLY,
    "R" => Qmf::ACCESS_READ_ONLY
  }

  DIRECTION = {
    "I" => Qmf::DIR_IN,
    "O" => Qmf::DIR_OUT,
    "IO" => Qmf::DIR_IN_OUT
  }
end

def declare_arg(name, type, options)
  opts = options.dup
  opts[:dir] = XmlConstants::DIRECTION[opts[:dir]] if opts[:dir] and XmlConstants::DIRECTION[opts[:dir]]
  {:name=>name,:type=>type,:options=>options}
end

# a declaration in the main app
class SchemaClass
  attr_accessor :name, :package
  
  def self.declare_class(name, package)
    kl = SchemaClass.new name, package
    yield kl if block_given?
    kl
  end
  
  def declare_property(name, type, options)
    declare_basic(name, type, options, @properties)
  end

  def declare_statistic(name, type, options)
    declare_basic(name, type, options, @statistics)
  end
  
  def declare_method(name, options)
    result = {:name => name, :args => [], :options => options.dup}
    yield result[:args] if block_given?
    @methods << result
    @methods[-1]
  end
  
  def initialize(pkg=nil, nm=nil)
    name, package = nm, pkg
    @properties = []
    @statistics = []
    @methods = []
  end
  
  private
  def declare_basic(name, type, options, where)
    opts = options.dup
    opts[:index] = true if opts[:index]
    type = XmlConstants::TYPES[type] if XmlConstants::TYPES[type] 
    where << {:name => name, :type => type, :options => opts}    
    where[-1]
  end
end
  
class QmfSchemaCodeGenerator  
  def initialize(fn)
    @package = nil
    @file = fn
    @doc = nil
    @indent = 0
    @filestack = [$stdout]
    @schema_classes = []
  end

  def main
    File::open(@file, "r") {|infile| @doc = REXML::Document.new(infile)}
    codegen_schema
  end

  private
  
  def outfile
    @filestack[-1] or $stdout
  end
  
  def inc_indent
    @indent = @indent + 2
  end
  
  def dec_indent
    @indent = @indent - 2
  end
  
  def pp(s)
    outfile.puts "#{' ' * @indent}#{s}\n"
  end
  
  def pdecl(kind, name, etc=nil)
    pp "#{kind} #{name}#{etc}"
    inc_indent
    yield if block_given?
    dec_indent
    pp "end"
  end
  
  def codegen_schema
    @package = @doc.root.attributes["package"]
    @package_list = @package.split(".")
    
    @package_dir = "./#{@package_list.join('/')}"
    
    FileUtils.mkdir_p @package_dir
    
    REXML::XPath.each(@doc.root, "/schema/class") do |elt|
      @classes << codegen_class elt
    end
  end

  def codegen_class(elt)
    classname = "#{elt.attributes['name']}"
    filename = "#{@package_dir}/#{classname}.rb"
    with_output_to filename do
      @package_list.map {|pkg| pkg.capitalize}.each do |modname|
        pp "module #{modname}"
        inc_indent
      end

      pp ""
      pdecl :class, classname do
        REXML::XPath.each(elt, "property") do |property|
          codegen_property property
        end
        
        REXML::XPath.each(elt, "method") do |method|
          codegen_method method
        end
      end
      
      @package_list.size.times do
        dec_indent
        pp "end"
      end
    end
  end
  
  def codegen_property(elt)
    pp ""
    pp "\# property #{elt.attributes['name']}"
    pdecl :def, "property_#{elt.attributes['name']}"
  end

  def codegen_statistic(elt)
    pp ""
    pp "\# statistic #{elt.attributes['name']}"
    pdecl :def, "statistic_#{elt.attributes['name']}"
  end
  
  def codegen_method(elt)
    pp ""
    pdecl :def, elt.attributes["name"], "(args)"
  end
  
  def with_output_to(filename, &action)
    File::open(filename, "w") do |of|
      @filestack << of
      
      action.call
      
      @filestack.pop
    end
  end
end

QmfSchemaCodeGenerator.new(ARGV[0]).main