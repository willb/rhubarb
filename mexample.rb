require 'manageable'

class Hello
   include SPQR::Manageable
   def hello(args)
     args[:result] = "Hello, #{args[:name]}!"
   end

   spqr_expose :hello do |args|
     args.declare :name, :string, :in
     args.declare :result, :string, :out
   end

   spqr_package :hello
   spqr_class :Hello
   spqr_statistic :people_greeted, :int
   spqr_property :service_name, :string
end

p Hello.spqr_meta
