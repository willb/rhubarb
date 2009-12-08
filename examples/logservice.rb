#!/usr/bin/env ruby

# This is a simple logging service that operates over QMF.  The API is
# pretty basic:
#   LogService is a singleton and supports the following methods:
#    * debug(msg)
#    * warn(msg)
#    * info(msg)
#    * error(msg)
#   each of which creates a log record of the given severity,
#   timestamped with the current time, and with msg as the log
#   message.
#
#   LogRecord corresponds to an individual log entry, and exposes the
#   following (read-only) properties:
#    * l_when (unsigned int), seconds since the epoch corresponding to
#      this log record's creation date
#    * severity (long string), a string representation of the severity
#    * msg (long string), the log message
#
# If you invoke logservice.rb with an argument, it will place the
# generated log records in that file, and they will persist between
# invocations.

require 'rubygems'
require 'spqr/spqr'
require 'spqr/app'
require 'rhubarb/rhubarb'

class LogService
  include SPQR::Manageable

  [:debug, :warn, :info, :error].each do |name|
    define_method name do |args|
      args['result'] = LogRecord.create(:l_when=>Time.now.to_i, :severity=>"#{name.to_s.upcase}", :msg=>args['msg'].dup)
    end
    
    expose name do |args|
      args.declare :msg, :lstr, :in
      args.declare :result, :objId, :out
    end
  end

  def self.find_all
    @@singleton ||= LogService.new
    [@@singleton]
  end

  def self.find_by_id(i)
    @@singleton ||= LogService.new
  end

  qmf_package_name :examples
  qmf_class_name :LogService
end

class LogRecord
  include SPQR::Manageable
  include Rhubarb::Persisting
  
  declare_column :l_when, :integer
  declare_column :severity, :string
  declare_column :msg, :string
  
  # XXX: rhubarb should create a find_all by default
  declare_query :find_all, "1"

  qmf_property :l_when, :uint
  qmf_property :severity, :lstr
  qmf_property :msg, :lstr

  qmf_package_name :examples
  qmf_class_name :LogRecord

  def spqr_object_id
    row_id
  end
end

TABLE = ARGV[0] or ":memory:" 
DO_CREATE = (TABLE == ":memory:" or not File.exist?(TABLE))

Rhubarb::Persistence::open(TABLE)

LogRecord.create_table if DO_CREATE

app = SPQR::App.new(:loglevel => :debug)
app.register LogService, LogRecord

app.main
