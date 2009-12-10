#!/usr/bin/env ruby

# SPQR:  Schema Processor for QMF/Ruby agents
# spqr-gen generates a skeleton QMF agent application from a schema file.
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

$: << File.expand_path(File.dirname(__FILE__))

require 'spqr/spqr'

def main
  $OUTDIR = "."
  $DO_RHUBARB = false

  op = OptionParser.new do |opts|
    opts.banner = "Usage spqr.rb [options] schema-file"
    
    opts.on("-n", "--noclobber", "don't overwrite pre-existing output files") do |noclob|
      $PP_WRITEMODE = File::WRONLY|File::EXCL|File::CREAT
    end
    
    opts.on("-d", "--output-dir DIR", "directory in which to place generated app and controllers") do |dir|
      $OUTDIR = dir
    end

    opts.on("-r", "--rhubarb", "enable support for rhubarb in generated code") do
      $DO_RHUBARB = true
    end
  end
  
  begin
    op.parse!
  rescue OptionParser::InvalidOption
    puts op
    exit
  end
    

  begin
    SPQR::QmfSchemaProcessor.new(ARGV[0]).main
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
