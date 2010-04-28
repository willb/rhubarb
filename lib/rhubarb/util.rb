# Timestamp function for Rhubarb.
#
# Copyright (c) 2009--2010 Red Hat, Inc.
#
# Author:  William Benton (willb@redhat.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0

require 'time'
require 'yaml'
require 'zlib'

module Rhubarb
  module Util
    # A higher-resolution timestamp
    def self.timestamp(tm=nil)
      tm ||= Time.now.utc
      (tm.tv_sec * 1000000) + tm.tv_usec
    end

    # Identity for objects that may be used as foreign keys
    def self.rhubarb_fk_identity(object)
      (object.row_id if object.class.ancestors.include? Persisting) || object
    end
    
    def self.blobify(obj)
      blobify_proc.call(obj)
    end
    
    def self.blobify_proc
      @blobify_proc ||= Proc.new {|x| x.is_a?(SQLite3::Blob) ? x : SQLite3::Blob.new(x)}
    end
    
    def self.zblobify_proc
      @zblobify_proc ||= Proc.new {|x| x.is_a?(SQLite3::Blob) ? x : SQLite3::Blob.new(Zlib::Deflate.deflate(x))}
    end
    
    def self.dezblobify_proc
      @dezblobify_proc ||= Proc.new {|x| Zlib::Inflate.inflate(x)}
    end
    
    def self.swizzle_object_proc
      @swizzle_object_proc ||= Proc.new do |x| 
        yamlrepr = x.to_yaml
        SQLite3::Blob.new(Zlib::Deflate.deflate(yamlrepr, Zlib::BEST_COMPRESSION))
      end
    end

    def self.deswizzle_object_proc
      @deswizzle_object_proc ||= Proc.new do |x|
        return nil if x.nil? || x == ""
        
        z = YAML.load(Zlib::Inflate.inflate(x))
        z.freeze
      end
    end

    def self.identity_proc
      @identity ||= Proc.new {|x| x}
    end
  end
end