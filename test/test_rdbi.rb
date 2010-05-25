require 'helper'

class TestRDBI< Test::Unit::TestCase
    def test_connect
        dbh = mock_connect
        assert(dbh)
        assert_kind_of(RDBI::Handle, dbh)

        dbh = RDBI.connect(RDBI::Driver::Mock, :username => :foo, :password => :bar)
        assert(dbh)
        assert_kind_of(RDBI::Handle, dbh)
        
        dbh = RDBI.connect("Mock", :username => :foo, :password => :bar)
        assert(dbh)
        assert_kind_of(RDBI::Handle, dbh)
    end

    def test_ping
        assert_equal(10, RDBI.ping(:Mock, :some => :arg))
        assert_equal(10, mock_connect.ping)
    end
end
