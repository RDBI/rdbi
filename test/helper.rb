require 'rubygems'
gem 'rdbi-driver-mock'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rdbi'
require 'rdbi/driver/mock'

# -- Fake an exceptional statement handle
module FaultyDB
  class Error < Exception; end
end

module RDBI
  class Driver
    class MockFaulty < RDBI::Driver
      def initialize(*args)
        super(MockFaulty::Database, *args)
      end
    end

    class MockFaulty::Database < Mock::DBH
      def new_statement(query)
        MockFaulty::Statement.new(query, self)
      end
    end

    class MockFaulty::Statement < Mock::STH
      def execute(*binds)
        raise ::FaultyDB::Error.new('Deadlocked, de-synchronized, corrupted, invalid, etc.')
      end
      alias :execute_modification :execute
    end
  end
end


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

  def out_convert(*args)
    RDBI::Type::Out.convert(*args)
  end

  def in_convert(*args)
    RDBI::Type::In.convert(*args)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
