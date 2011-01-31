require 'helper'

class TestStatement < Test::Unit::TestCase
  attr_accessor :dbh

  def setup
    @dbh = mock_connect
  end

  def teardown
    @dbh.disconnect
  end

  def test_01_allocation
    sth = dbh.new_statement("some query")
    assert(sth)
    assert_kind_of(RDBI::Statement, sth)
    assert_kind_of(RDBI::Database, sth.dbh)
    assert_equal(sth.query, "some query")
    sth.finish
  end

  def test_02_accessors
    sth = dbh.new_statement("some query")
    assert(sth)
    assert(!sth.finished?)
    assert(!sth.finished)
    sth.finish
  end

  def test_03_execute
    res = dbh.execute("select * from foo where bar=?", 1)
    assert_kind_of(RDBI::Result, res)
    assert_equal(%W[10 11 12 13 14].collect { |x| [x] }, res.fetch(:all))

    sth = dbh.prepare("select * from foo where bar=?")
    assert_kind_of(RDBI::Statement, sth)
    assert_kind_of(RDBI::Driver::Mock::STH, sth)
    assert_respond_to(sth, :new_execution)
    assert_respond_to(sth, :execute)
    res = sth.execute(1)
    assert_equal(%W[10 11 12 13 14].map { |x| [x] }, res.fetch(:all))
    sth.finish
    
    sth = dbh.prepare("select * from foo where bar=?bar and foo=?")
    res = sth.execute({:bar => "10"}, "1")
    assert_equal(
      [ { :bar => "10" }, "1" ],
      res.binds
    )
    sth.finish
  end

  def test_04_finish
    sth = dbh.prepare("select * from foo where bar=?")

    assert(!sth.finished?)
    sth.finish
    assert(sth.finished?)
    assert_raises(StandardError) { sth.execute }
    sth.finish
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
