require 'helper'

class TestPool < Test::Unit::TestCase
    def create_pool(name=:default)
        pool = RDBI::Pool.new(name, [:Mock, {:username => :foo}])
    end

    def test_01_construction
        pool = create_pool(:test_01)
        assert(pool)
        assert_kind_of(RDBI::Pool, pool)
    end

    def test_02_class_accessors
        assert(!RDBI::Pool[:test_02])
        create_pool(:test_02)

        assert(RDBI::Pool[:test_02])
    end

    def test_03_pooling!
        pool = create_pool(:test_03)
        assert_raise(ArgumentError) do
            6.times do
                RDBI::Pool[:test_03].add_connection
            end
        end

        assert_equal(0, pool.last_index)
        dbh = pool.get_dbh
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)
        assert(dbh.connected?)

        pool.disconnect

        assert_equal(1, pool.last_index)
        dbh = pool.get_dbh
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)
        assert(dbh.connected?)

        # XXX HACK for testing
        pool.instance_variable_set(:@last_index, 5) 
        dbh = pool.get_dbh
        assert(dbh)
        assert_kind_of(RDBI::Database, dbh)
        assert(dbh.connected?)
        assert_equal(1, pool.last_index)
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
