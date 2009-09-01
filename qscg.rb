#!/usr/bin/env ruby

require 'rexml/document'

class QmfSchemaCodeGenerator
  def initialize(fn)
    @package = nil
    @file = fn
    @doc = nil
    @indent = 0
    @filestack = [$stdout]
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
  
  def pp(s, file=$stdout)
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
    package_list = @package.split(".").map {|pkg| pkg.capitalize}
    package_list.each do |modname|
      pp "module #{modname}"
      inc_indent
    end
    
    REXML::XPath.each(@doc.root, "/schema/class") do |elt|
      codegen_class elt
    end
    
    package_list.size.times do
      dec_indent
      pp "end"
    end
  end

  def codegen_class(elt)
    pp ""
    pdecl :class, elt.attributes["name"] do
      REXML::XPath.each(elt, "property") do |property|
        codegen_property property
      end
      
      REXML::XPath.each(elt, "method") do |method|
        codegen_method method
      end
    end
  end
  
  def codegen_property(elt)
    pp "\# property #{elt.attributes['name']}"
    pdecl :def, "property_#{elt.attributes['name']}"
  end
  
  def codegen_method(elt)
    pp ""
    pdecl :def, elt.attributes["name"], "(args)"
  end
end

QmfSchemaCodeGenerator.new(ARGV[0]).main