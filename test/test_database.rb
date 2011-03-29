require 'helper'

class TestDatabase < Test::Unit::TestCase
  def setup
    @dbh = mock_connect
  end

  def assert_transaction(count)
    in_transaction = @dbh.instance_variable_get("@in_transaction") ||
      @dbh.instance_variable_get(:@in_transaction)
    assert_equal(count, in_transaction)

    if in_transaction > 0
      assert(@dbh.in_transaction?)
    end
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
      assert_transaction(1)
    end

    assert_transaction(0)
    assert_equal(true, res)

    # rollback works when commit fails
    @dbh.next_action = proc do |*args|
      raise StandardError, "should call rollback"
    end

    assert_raises(StandardError) do
      @dbh.transaction do |dbh|
        assert_transaction(1)
        true
      end
    end

    assert_transaction(0)
    assert_equal(true, res)

    # rollback works when transaction fails

    @dbh.next_action = proc { |*args| true }

    assert_raises(StandardError) do
      @dbh.transaction do |dbh|
        assert_transaction(1)

        raise StandardError, "should call rollback"
        nil
      end
    end

    assert_transaction(0)
    assert_equal(true, res)

    # commit called within transaction

    @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" }; "commit called" }

    res = @dbh.transaction do |dbh|
      assert_transaction(1)

      dbh.commit

      assert_transaction(0)
      true
    end

    assert_not_equal("rollback called", res)
    assert_not_equal("commit called", res)

    # rollback called within transaction

    @dbh.next_action = proc { |*args| @dbh.next_action = proc { raise "shit" }; "commit called" }

    res = @dbh.transaction do |dbh|
      assert_transaction(1)

      dbh.rollback

      assert_transaction(0)
    end

    assert_not_equal("rollback called", res)
    assert_not_equal("commit called", res)
  end

  def test_03_last_query
    @dbh.prepare("here's the last query #1").finish
    assert_equal("here's the last query #1", @dbh.last_query)

    @dbh.prepare("here's the last query #2").finish
    assert_equal("here's the last query #2", @dbh.last_query)

    @dbh.execute("here's the last query #3").finish
    assert_equal("here's the last query #3", @dbh.last_query)

    @dbh.execute("here's the last query #4").finish
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
    
    query = @dbh.preprocess_query("select * from foo where bind=?foo and bind2=?bar", { :foo => "fo'o", :bar => "ba''r" })
    assert_equal("select * from foo where bind='fo''o' and bind2='ba''''r'", query)
    
    query = @dbh.preprocess_query("select * from foo where bind=?foo and bind2=?bar", { :foo => "fo'o"}, { :bar => "ba''r" })
    assert_equal("select * from foo where bind='fo''o' and bind2='ba''''r'", query)
    
    query = @dbh.preprocess_query("select * from foo where bind=?foo and bind2=?bar and bind3=?", { :foo => "fo'o"}, { :bar => "ba''r" }, "quux")
    assert_equal("select * from foo where bind='fo''o' and bind2='ba''''r' and bind3='quux'", query)
  end

  def test_05_prepare_execute
    sth = @dbh.prepare("some statement")
    assert(sth)
    assert_kind_of(RDBI::Statement, sth)

    res = @dbh.execute("some other statement")
    assert(res)
    assert_kind_of(RDBI::Result, res)
    sth.finish
  end

  def test_06_last_statement
    sth = @dbh.prepare("some statement")
    assert(sth)
    assert_kind_of(RDBI::Statement, sth)

    assert_equal(@dbh.last_statement.object_id, sth.object_id)

    res = @dbh.execute("some other statement")
    assert(res)
    assert_kind_of(RDBI::Result, res)
    assert_not_equal(@dbh.last_statement.object_id, sth.object_id)
    sth.finish
  end

  def test_07_nested_transactions
    @dbh.transaction do
      @dbh.transaction do
        assert_transaction(2)
        @dbh.commit
        assert_transaction(1)
        # XXX should this be how it works?
        @dbh.commit
        assert_transaction(0)
      end
    end

    @dbh.transaction do
      @dbh.transaction do
        assert_transaction(2)
        @dbh.commit
        assert_transaction(1)
      end
      @dbh.commit
      assert_transaction(0)
    end

    @dbh.transaction do
      @dbh.transaction do
        assert_transaction(2)
        @dbh.rollback
        assert_transaction(1)
        # XXX should this be how it works?
        @dbh.rollback
        assert_transaction(0)
      end
    end

    @dbh.transaction do
      @dbh.transaction do
        assert_transaction(2)
        @dbh.rollback
        assert_transaction(1)
      end
      @dbh.rollback
      assert_transaction(0)
    end
  end

  def test_08_block_form
    my_sth = nil
    my_res = nil

    # ordinary execution
    @dbh.prepare("some statement") do |sth|
      assert(sth)
      assert_respond_to(sth, :execute)
      res = sth.execute
      assert(res)
      my_sth = sth
      assert(! my_sth.finished?)
    end

    assert(my_sth.finished?)

    # and exceptional
    begin
      @dbh.prepare("some statement") do |sth|
        assert(sth)
        assert_respond_to(sth, :execute)
        res = sth.execute
        assert(res)
        my_sth = sth
        assert(! my_sth.finished?)
        raise "Blam!"
      end
    rescue
    end

    assert(my_sth.finished?)

    # Database#execute &block

    my_res = nil
    block_ret = @dbh.execute("some statement") do |res|
                  my_res = res
                  assert(res)
                  assert_kind_of(RDBI::Result, res)
                  "BLOCK RETURN"
                end

    assert_kind_of(RDBI::Result, my_res)
    # Result#finish implies Statement#finish, nil'ing
    assert(my_res.sth.nil?,
           'Database#execute &p did not finish its Result')
    assert(!block_ret.kind_of?(RDBI::Result),
           'Database#execute &block wrongly returned its Result')
    assert_equal("BLOCK RETURN", block_ret,
                 "Database#execute &block didn't return the return value of &block")
  end

  def test_09_statement_allocation
    sth = @dbh.prepare("some statement")
    assert(sth)

    assert_equal(@dbh.open_statements.keys.length, 1)

    @dbh.disconnect

    assert_equal(@dbh.open_statements.keys.length, 0)

    @dbh = mock_connect
    sth = @dbh.prepare("some statement")
    sth.finish
    assert_equal(@dbh.open_statements.length, 0)
    @dbh.disconnect
  end

  def teardown
    @dbh.disconnect
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
