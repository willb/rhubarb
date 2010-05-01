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
    
    def self.blobify_proc
      @blobify_proc ||= Proc.new {|obj| obj.is_a?(SQLite3::Blob) ? obj : SQLite3::Blob.new(obj)}
    end
    
    def self.zblobify_proc
      @zblobify_proc ||= Proc.new {|obj| obj.is_a?(SQLite3::Blob) ? obj : SQLite3::Blob.new(Zlib::Deflate.deflate(obj))}
    end
    
    def self.dezblobify_proc
      @dezblobify_proc ||= Proc.new do |obj| 
        return nil if obj.nil? || obj == ""
        Zlib::Inflate.inflate(obj)
      end
    end
    
    def self.swizzle_object_proc
      @swizzle_object_proc ||= Proc.new do |obj| 
        yamlrepr = obj.to_yaml
        SQLite3::Blob.new(Zlib::Deflate.deflate(yamlrepr, Zlib::BEST_COMPRESSION))
      end
    end

    def self.deswizzle_object_proc
      @deswizzle_object_proc ||= Proc.new do |zy_obj|
        return nil if zy_obj.nil? || zy_obj == ""
        
        obj = YAML.load(Zlib::Inflate.inflate(zy_obj))
        obj.freeze
      end
    end
  end
end