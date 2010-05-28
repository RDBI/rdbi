require 'helper'

class TestResult < Test::Unit::TestCase
  def setup
    @dbh = mock_connect 
  end

  def teardown
    @dbh.disconnect
  end
  
  def mock_result
    RDBI::Result.new((0..9).to_a.map { |x| [x-1, x, x+1] }, RDBI::Schema.new, @dbh.prepare("foo"), [1])
  end

  def get_index(res)
    get_guts(res)[:index]
  end

  def get_guts(res)
    h = { }
    %W[index schema binds sth data].collect(&:to_sym).each do |sym|
      h[sym] = res.instance_variable_get("@#{sym}") || res.instance_variable_get("@#{sym}".to_sym)
    end

    return h
  end

  def test_01_init
    res = mock_result
    assert(res)
    assert_kind_of(RDBI::Result, res)

    guts = get_guts(res)

    assert_kind_of(RDBI::Statement, guts[:sth])
    assert_kind_of(RDBI::Statement, res.sth)
    assert_equal(res.sth, guts[:sth])

    assert_kind_of(RDBI::Schema, guts[:schema])
    assert_kind_of(RDBI::Schema, res.schema)
    assert_equal(res.schema, guts[:schema])

    assert_kind_of(Array, guts[:binds])
    assert_equal(res.binds, guts[:binds])
    assert_not_equal(res.binds.object_id, guts[:binds].object_id)
    assert_equal([1], guts[:binds])
  end

  def test_02_responds
    res = mock_result

    %W[
      schema
      sth
      driver
      rows
      complete
      complete?
      eof
      eof?
      has_data
      has_data?
      each
      inject
      rewind
      as
      fetch
      read
      raw_fetch
      finish 
    ].collect(&:to_sym).each do |sym|
      assert_respond_to(res, sym)
    end
  end

  def test_03_fetch_works
    res = mock_result
    assert_equal([[-1,0,1]], res.fetch)
    assert_equal(1, get_index(res))

    assert_equal((1..9).to_a.map { |x| [x-1, x, x+1] }, res.fetch(9))
    assert_equal(10, get_index(res))
    assert_equal([], res.fetch)
  end

  def test_04_finish_works
    res = mock_result
    res.finish

    guts = get_guts(res)

    guts.values.each { |value| assert_nil(value) } 
  end
  
  def test_05_enumerable_works
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
