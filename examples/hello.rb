require 'spqr/spqr'
require 'spqr/app'
require 'logger'

class Hello
   include SPQR::Manageable
   def hello(args)
     args["result"] = "Hello, #{args['name']}!"
   end

   spqr_expose :hello do |args|
     args.declare :name, :lstr, :in
     args.declare :result, :lstr, :out
   end

   spqr_package :hello
   spqr_class :Hello
   spqr_statistic :people_greeted, :int
   spqr_property :service_name, :lstr
   
   def Hello.find_all 
     [Hello.new]
   end

   def Hello.find_by_id(id)
     Hello.new
   end
end

app = SPQR::App.new(:loglevel => :debug)
app.register Hello

app.main
