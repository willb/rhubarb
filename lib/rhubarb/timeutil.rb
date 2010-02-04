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

module Rhubarb
  module TimeUtil
    def self.timestamp(tm=nil)
      tm ||= Time.now.utc
      (tm.tv_sec * 1000000) + tm.tv_usec
    end
  end
end