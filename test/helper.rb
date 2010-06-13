require 'rubygems'
gem 'test-unit'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rdbi'
require 'rdbi/driver/mock'

class Test::Unit::TestCase
  def mock_connect
    RDBI.connect(:Mock, :username => 'foo', :password => 'bar')
  end

  # type conversion column
  def tcc(type)
    col = RDBI::Column.new
    col.ruby_type = type
    col
  end

  def convert(*args)
    RDBI::Type::Out.convert(*args)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
