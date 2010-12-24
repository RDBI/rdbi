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
    assert_raise(ArgumentError.new("too many handles in this pool (max: 5)")) do
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

    pool = create_pool(:test_03_2)
    5.times do
      dbh = pool.get_dbh
      assert(dbh.connected?)
    end
  end

  def test_04_remove
    pool = create_pool(:test_04).add_connection
    dbh = pool.get_dbh

    assert(pool.handles.map(&:object_id).include?(dbh.object_id))
    pool.remove(dbh)
    assert(!pool.handles.map(&:object_id).include?(dbh.object_id))
  end

  def test_05_dis_reconnect
    pool = create_pool(:test_05)
    4.times { pool.add_connection }

    pool.disconnect

    pool.handles.each do |dbh|
      assert(!dbh.connected?)
    end

    pool.reconnect

    pool.handles.each do |dbh|
      assert(dbh.connected?)
    end
  end

  def test_06_ping_and_up
    pool = create_pool(:test_06)
    4.times { pool.add_connection }
    assert_equal(10, pool.ping)

    assert(pool.up)

    pool.handles[0].disconnect

    assert(!pool.up)
  end

  def test_07_resize
    pool = create_pool(:test_07).add_connection
    4.times { pool.add_connection }

    handles = pool.resize(2) 

    assert_equal(2, pool.max)

    handles.each do |dbh|
      assert(!pool.handles(&:object_id).include?(dbh.object_id))
    end

    assert_equal(2, pool.handles.size)

    assert_equal(0, pool.last_index)

    3.times do
      pool.get_dbh
    end

    assert_equal(1, pool.last_index)

    pool = create_pool(:test_07_2)
    pool.add_connection
    handles = pool.resize(2)
    assert_equal([], handles)

    # check the ability to cull disconnected objects automatically while
    # preferring connected ones.
    pool = create_pool(:test_07_3)
    5.times { pool.add_connection }
    dbh = pool.get_dbh
    pool.disconnect
    dbh.reconnect
    handles = pool.resize(2)
    assert_equal(2, pool.handles.size)
    assert_equal(3, handles.size)
    assert(!handles.map(&:object_id).include?(dbh.object_id))
  end

  def test_08_enumerable
    assert_equal(
      [
        :test_01,
        :test_02,
        :test_03,
        :test_03_2,
        :test_04,
        :test_05,
        :test_06,
        :test_07,
        :test_07_2,
        :test_07_3
      ], 
      RDBI::Pool.keys.map(&:to_s).sort.map(&:to_sym)
    )

    assert_equal(10, RDBI::Pool.values.count)
    assert_kind_of(RDBI::Pool, RDBI::Pool.values[0])

    count = 0
    RDBI::Pool.each do |name, pool|
      count += 1
      assert_kind_of(Symbol, name)
      assert_kind_of(RDBI::Pool, pool)
    end

    assert(10, count)
    assert_respond_to(RDBI::Pool, :map)

    pool = create_pool(:test_08)

    assert(pool)
    assert_kind_of(RDBI::Pool, pool)
    assert_respond_to(pool, :each)

    count = 0

    3.times { pool.add_connection }

    pool.each do |dbh|
      count += 1
      assert_kind_of(RDBI::Database, dbh)
    end

    assert_equal(3, count)

    assert_respond_to(pool, :map)
  end

  def test_09_alternative_connect_syntax
    pool = RDBI::Pool.new(name, { :driver => :Mock, :database => ":memory:", :username => "foo" })
    dbh = pool.get_dbh
    assert(dbh)
    assert_kind_of(RDBI::Database, dbh)

    assert_equal([:Mock, [:database, ":memory:"], [:username, "foo"]], pool.instance_variable_get(:@connect_args))
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
