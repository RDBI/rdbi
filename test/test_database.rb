require 'helper'

class TestPool < Test::Unit::TestCase
    def setup
        @dbh = mock_connect
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
            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(true, in_transaction)
        end

        in_transaction = @dbh.instance_variable_get("@in_transaction") || 
            @dbh.instance_variable_get(:@in_transaction)
        assert_equal(false, in_transaction)

        assert_equal(true, res)
        
        # rollback works when commit fails

        @dbh.next_action = proc do |*args|
            raise StandardError, "should call rollback"
        end

        res = @dbh.transaction do |dbh|
            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(true, in_transaction)

            true
        end

        in_transaction = @dbh.instance_variable_get("@in_transaction") || 
            @dbh.instance_variable_get(:@in_transaction)
        assert_equal(false, in_transaction)

        assert_equal("rollback called", res)

        # rollback works when transaction fails
        
        @dbh.next_action = proc { |*args| true }

        res = @dbh.transaction do |dbh|
            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(true, in_transaction)

            raise StandardError, "should call rollback"
            nil
        end
        
        in_transaction = @dbh.instance_variable_get("@in_transaction") || 
            @dbh.instance_variable_get(:@in_transaction)
        assert_equal(false, in_transaction)

        assert_equal("rollback called", res)

        # commit called within transaction
        
        @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" } }

        res = @dbh.transaction do |dbh|
            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(true, in_transaction)

            dbh.commit

            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(false, in_transaction)

            true
        end

        assert_not_equal("rollback called", res)

        # rollback called within transaction

        @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" } }

        res = @dbh.transaction do |dbh|
            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(true, in_transaction)

            dbh.rollback

            in_transaction = @dbh.instance_variable_get("@in_transaction") || 
                @dbh.instance_variable_get(:@in_transaction)
            assert_equal(false, in_transaction)

            true
        end
        
        assert_not_equal("rollback called", res)
    end

    def teardown
        @dbh.disconnect
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
