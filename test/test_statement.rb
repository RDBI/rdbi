require 'helper'

class TestStatement < Test::Unit::TestCase
    attr_accessor :dbh

    def setup
        @dbh = mock_connect
    end

    def teardown
        @dbh.disconnect
    end

    def test_01_allocation
        sth = dbh.new_statement("some query")
        assert(sth)
        assert_kind_of(RDBI::Statement, sth)
        assert_kind_of(RDBI::Database, sth.dbh)
        assert_equal(sth.query, "some query")
    end

    def test_02_accessors
        sth = dbh.new_statement("some query")
        assert(sth)
        assert_kind_of(Mutex, sth.mutex)
        assert(!sth.finished?)
        assert(!sth.finished)
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
