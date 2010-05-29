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
  end

  def test_02_accessors
    sth = dbh.new_statement("some query")
    assert(sth)
    assert_kind_of(Mutex, sth.mutex)
    assert(!sth.finished?)
    assert(!sth.finished)
  end

  # XXX 
  #
  # THIS TEST WILL CHANGE DRASTICALLY VERY SOON. PLEASE LEAVE BE FOR NOW.
  #
  # XXX
  def test_03_execute
    res = dbh.execute("select * from foo where bar=?", 1)
    assert_kind_of(RDBI::Result, res)
    assert_equal(%W[1 2 3 4 5].map { |x| [x.to_i] }, res.fetch(:all))

    sth = dbh.prepare("select * from foo where bar=?")
    assert_kind_of(RDBI::Statement, sth)
    assert_kind_of(RDBI::Driver::Mock::STH, sth)
    assert_respond_to(sth, :new_execution)
    assert_respond_to(sth, :execute)
    res = sth.execute(1)
    assert_equal(%W[1 2 3 4 5].map { |x| [x.to_i] }, res.fetch(:all))
  end

  def test_04_finish
    sth = dbh.prepare("select * from foo where bar=?")

    assert(!sth.finished?)
    sth.finish
    assert(sth.finished?)
    assert_raises(StandardError.new("you may not execute a finished handle")) { sth.execute }
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
