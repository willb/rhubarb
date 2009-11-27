require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'spqr/spqr'
require 'spqr/app'
require 'rhubarb/rhubarb'

class Test::Unit::TestCase
end
