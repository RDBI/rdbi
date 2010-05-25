require 'helper'

class TestRDBI< Test::Unit::TestCase
    def test_connect
        dbh = RDBI.connect(:Mock, :username => :foo, :password => :bar)
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)

        dbh = RDBI.connect(RDBI::Driver::Mock, :username => :foo, :password => :bar)
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)
        
        dbh = RDBI.connect("Mock", :username => :foo, :password => :bar)
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)
    end

    def test_last_dbh
        dbh = mock_connect

        assert(RDBI.last_dbh)
        assert(dbh.object_id == RDBI.last_dbh.object_id)
    end

    def test_ping
        assert_equal(10, RDBI.ping(:Mock, :some => :arg))
        assert_equal(10, mock_connect.ping)
    end
end
