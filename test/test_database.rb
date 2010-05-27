require 'helper'

class TestPool < Test::Unit::TestCase
    def setup
        @dbh = mock_connect
    end

    def assert_transaction(bool)
        in_transaction = @dbh.instance_variable_get("@in_transaction") || 
            @dbh.instance_variable_get(:@in_transaction)
        assert_equal(bool, in_transaction)
    end

    def test_01_ping
        assert_equal(10, @dbh.ping)
    end

    def test_02_transaction
        # commit works
        
        @dbh.next_action = proc do |*args|
            return true
        end

        res = @dbh.transaction do |dbh|
            assert_transaction(true)
        end

        assert_transaction(false)
        assert_equal(true, res)
        
        # rollback works when commit fails

        @dbh.next_action = proc do |*args|
            raise StandardError, "should call rollback"
        end

        res = @dbh.transaction do |dbh|
            assert_transaction(true)
            true
        end

        assert_transaction(false)
        assert_equal("rollback called", res)

        # rollback works when transaction fails
        
        @dbh.next_action = proc { |*args| true }

        res = @dbh.transaction do |dbh|
            assert_transaction(true)

            raise StandardError, "should call rollback"
            nil
        end
       
        assert_transaction(false)
        assert_equal("rollback called", res)

        # commit called within transaction
        
        @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" }; "commit called" }

        res = @dbh.transaction do |dbh|
            assert_transaction(true)

            dbh.commit

            assert_transaction(false)
            true
        end

        assert_not_equal("rollback called", res)
        assert_not_equal("commit called", res)

        # rollback called within transaction

        @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" }; "commit called" }

        res = @dbh.transaction do |dbh|
            assert_transaction(true)

            dbh.rollback

            assert_transaction(false)
        end
        
        assert_not_equal("rollback called", res)
        assert_not_equal("commit called", res)
    end

    def test_03_last_query
        @dbh.prepare("here's the last query #1")
        assert_equal("here's the last query #1", @dbh.last_query)

        @dbh.prepare("here's the last query #2")
        assert_equal("here's the last query #2", @dbh.last_query)
        
        @dbh.execute("here's the last query #3")
        assert_equal("here's the last query #3", @dbh.last_query)
        
        @dbh.execute("here's the last query #4")
        assert_equal("here's the last query #4", @dbh.last_query)

        @dbh.preprocess_query("here's the last query #5")
        assert_equal("here's the last query #5", @dbh.last_query)
        
        @dbh.preprocess_query("here's the last query #6")
        assert_equal("here's the last query #6", @dbh.last_query)
    end

    def test_04_preprocess_query
        query = @dbh.preprocess_query("select * from foo where bind=? and bind2=?", "foo", "bar")
        assert_equal("select * from foo where bind='foo' and bind2='bar'", query)
        
        query = @dbh.preprocess_query("select * from foo where bind=? and bind2=?", "fo'o", "ba''r")
        assert_equal("select * from foo where bind='fo''o' and bind2='ba''''r'", query)
    end

    def teardown
        @dbh.disconnect
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
