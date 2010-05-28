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
    res.instance_variable_get("@index") || res.instance_variable_get(:@index)
  end

  def test_01_init
    res = mock_result
    assert(res)
    assert_kind_of(RDBI::Result, res)
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
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
