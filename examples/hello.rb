require 'spqr/spqr'
require 'spqr/app'
require 'logger'

class Hello
   include SPQR::Manageable

  # Input (in and inout) parameters are passed to exposed methods in
  # the order they are declared in the expose block (see below).
   def hello(name)
     # We will keep track of the number of people we have greeted over
     # the lifetime of this agent (see below for the people_greeted
     # statistic declaration).
     @people_greeted = @people_greeted + 1

     # In methods that return only one value --- that is, those which
     # have only one parameter that is either out or inout --- the
     # return value is provided normally.  Methods that have multiple
     # out and inout parameters should return a list that includes the
     # returned values in the order they are specified in the expose block.
     "Hello, #{name}!"
    end

   # This block indicates that we intend to expose the "hello" method
   # over QMF, that "name" is the first (and only) formal input
   # parameter, and "result" is the first (and only) formal output
   # parameter.  Argument declarations include a name, a type, a
   # direction, and optional keyword arguments.
   expose :hello do |args|
     args.declare :name, :lstr, :in
     args.declare :result, :lstr, :out
   end

   # This is the method that will be called to get the value of the
   # service_name property
   def service_name
     @service_name = "HelloAgent"
   end

   # The following two declarations provide the QMF package and class
   # names for the published class.  These can be provided either as
   # symbols or as strings.  If the class name is omitted, it will be
   # generated from the class name.
   qmf_package_name :hello
   qmf_class_name :Hello

   # The following two declarations create named QMF statistics and
   # properties with given types.  The value for a statistic or
   # property is taken from the return values of the instance method
   # with the same name as that statistic or property.  If a method
   # with this name does not exist, one is created with attr_reader
   # and attr_writer.
   qmf_statistic :people_greeted, :int
   qmf_property :service_name, :lstr
   
   # These should return the same object for the lifetime of the agent
   # app, since this example has no persistent objects.
   def Hello.find_all 
     @@hellos ||= [Hello.new]
   end

   def Hello.find_by_id(id)
     @@hellos ||= [Hello.new]
     @@hellos[0]
   end

   def initialize
     @people_greeted = 0
   end
end

app = SPQR::App.new(:loglevel => :debug)
app.register Hello

app.main
