require 'managedobject'

class Hello
   include SPQR::Manageable
   def hello(args)
     args[:result] = "Hello, #{args[:name]}!"
   end

   expose :hello do |args|
     args.declare :name, :string, :in
     args.declare :result, :string, :out
   end
end

p Hello.spqr_meta
