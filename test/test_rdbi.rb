require 'helper'

class TestRDBI < Test::Unit::TestCase
  def test_01_connect
    dbh = RDBI.connect(:Mock, :username => :foo, :password => :bar)
    assert(dbh)
    assert_kind_of(RDBI::Database, dbh)

    dbh = RDBI.connect(RDBI::Driver::Mock, :username => :foo, :password => :bar)
    assert(dbh)
    assert_kind_of(RDBI::Database, dbh)

    dbh = RDBI.connect("Mock", :username => :foo, :password => :bar)
    assert(dbh)
    assert_kind_of(RDBI::Database, dbh)

    assert_raise(ArgumentError) { RDBI.connect(1, :user => :blah) }
  end

  def test_02_last_dbh
    dbh = mock_connect

    assert(RDBI.last_dbh)
    assert(dbh.object_id == RDBI.last_dbh.object_id)
  end

  def test_03_ping
    assert_equal(10, RDBI.ping(:Mock, :some => :arg))
    assert_equal(10, mock_connect.ping)
  end

  def test_04_connect_cached
    dbh = RDBI.connect_cached(:Mock, :username => :foo)

    assert(dbh)
    assert_kind_of(RDBI::Database, dbh)
    assert_equal(RDBI::Pool[:default].handles[0], dbh)

    new_dbh = RDBI.connect_cached(:Mock, :username => :foo)

    assert(new_dbh)
    assert_kind_of(RDBI::Database, new_dbh)
    assert_equal(RDBI::Pool[:default].handles[1], new_dbh)
    assert_not_equal(dbh, new_dbh)

    3.times { RDBI.connect_cached(:Mock, :username => :foo) }

    assert_equal(dbh.object_id, RDBI.connect_cached(:Mock, :username => :foo).object_id)
    assert_equal(new_dbh.object_id, RDBI.connect_cached(:Mock, :username => :foo).object_id)

    # different pool

    pool_dbh = RDBI.connect_cached(:Mock, :username => :foo, :pool_name => :foo)

    assert_not_equal(dbh, pool_dbh)
    assert_not_equal(new_dbh, pool_dbh)
    assert_equal(RDBI::Pool[:foo].handles[0], pool_dbh)
  end

  def test_05_pool
    dbh = RDBI.connect_cached(:Mock, :username => :foo, :pool_name => :test_05)
    assert_equal(RDBI.pool(:test_05).handles[0], dbh)
  end

  def test_06_re_disconnect_all
    RDBI.disconnect_all
    connected_size = RDBI.all_connections.select(&:connected).size
    assert_equal(0, connected_size)

    total_size = RDBI.all_connections.size
    RDBI.reconnect_all
    connected_size = RDBI.all_connections.select(&:connected).size
    assert_equal(connected_size, total_size)
  end

  def test_07_all_connections
    total_size = RDBI.all_connections.size
    mock_connect
    assert_equal(RDBI.all_connections.size, total_size + 1)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
