#!/usr/bin/env ruby

# Constants for SQPR
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

end