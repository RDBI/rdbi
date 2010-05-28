require 'helper'

class TestResult < Test::Unit::TestCase
  def setup
    @dbh = mock_connect 
  end

  def teardown
    @dbh.disconnect
  end
  
  def mock_result
    RDBI::Result.new([[1]], RDBI::Schema.new, @dbh.prepare("foo"), [1])
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
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
