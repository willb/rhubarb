$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rhubarb/rhubarb'
require 'test/unit'
require 'zlib'
require 'set'
require 'ostruct'

class Test::Unit::TestCase
end
