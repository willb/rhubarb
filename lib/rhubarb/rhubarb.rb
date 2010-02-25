# Rhubarb is a simple persistence layer for Ruby objects and SQLite.
# For now, see the test cases for example usage.
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

require 'set'
require 'sqlite3'
require 'rhubarb/util'
require 'rhubarb/persistence'
require 'rhubarb/column'
require 'rhubarb/reference'
require 'rhubarb/classmixins'
require 'rhubarb/persisting'
