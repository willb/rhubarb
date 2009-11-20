#!/usr/bin/env ruby

require 'spqr/spqr'
require 'spqr/app'
require 'rhubarb/rhubarb'

class LogService
  include SPQR::Manageable

  [:debug, :warn, :info, :error].each do |name|
    define_method name do |args|
      args['result'] = LogRecord.create(:l_when=>Time.now.to_i, :severity=>"#{name.to_s.upcase}", :msg=>args['msg'].dup)
    end
    
    spqr_expose name do |args|
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

  spqr_package :examples
  spqr_class :LogService
end

class LogRecord
  include SPQR::Manageable
  include Rhubarb::Persisting
  
  declare_column :l_when, :integer
  declare_column :severity, :string
  declare_column :msg, :string
  
  # XXX: rhubarb should create a find_all by default
  declare_query :find_all, "1"

  spqr_property :l_when, :uint
  spqr_property :severity, :lstr
  spqr_property :msg, :lstr

  spqr_package :examples
  spqr_class :LogRecord
end

Rhubarb::Persistence::open(":memory:")
LogRecord.create_table

app = SPQR::App.new(:loglevel => :debug)
app.register LogService, LogRecord

app.main
