require 'rubygems'
gem 'test-unit'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rdbi'

class Test::Unit::TestCase
    def mock_connect
        RDBI.connect(:Mock, :username => 'foo', :password => 'bar')
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
