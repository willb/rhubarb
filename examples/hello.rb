require 'spqr/spqr'
require 'spqr/app'
require 'logger'

class Hello
   include SPQR::Manageable
   def hello(args)
     @people_greeted ||= 0
     @people_greeted = @people_greeted + 1
     args["result"] = "Hello, #{args['name']}!"
    end

   spqr_expose :hello do |args|
     args.declare :name, :lstr, :in
     args.declare :result, :lstr, :out
   end

   # This is for the service_name property
   def service_name
     @service_name = "HelloAgent"
   end

   spqr_package :hello
   spqr_class :Hello
   spqr_statistic :people_greeted, :int
   spqr_property :service_name, :lstr
   
   # These should return the same object for the lifetime of the agent
   # app, since this example has no persistent objects.
   def Hello.find_all 
     @@hellos ||= [Hello.new]
   end

   def Hello.find_by_id(id)
     @@hellos ||= [Hello.new]
     @@hellos[0]
   end
end

app = SPQR::App.new(:loglevel => :debug)
app.register Hello

app.main
