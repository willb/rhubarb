# SPQR:  Schema Processor for QMF/Ruby agents
#
# Managed object mixin.
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
  class BlankSlate
    instance_methods.each do |m|
      undef_method m unless m.to_s =~ /^__|freeze|method_missing|respond_to?|initialize/
    end
  end

  class ManageableMeta < BlankSlate
    attr_accessor :class, :package, :description, :methods
    def initialize
      @methods = []
    end
  end

  module Manageable
    def self.included(other)
      def other.spqr_meta
        @spqr_meta ||= ::SPQR::MClass.new
      end

      # Exposes this method to QMF
      def other.expose(bar)
        puts "#{self}.foo(#{bar})"
      end
    end
  end
end
