require 'helper'

class TestResult < Test::Unit::TestCase
  def setup
    @dbh = mock_connect 
  end

  def teardown
    @dbh.disconnect
  end

  def generate_data
    (0..9).to_a.map { |x| [x-1, x, x+1] }
  end
  
  def mock_result
    names = [:zero, :one, :two]
    RDBI::Result.new(generate_data, RDBI::Schema.new((0..2).to_a.map { |x| RDBI::Column.new(names[x], :integer, :default) }), @dbh.prepare("foo"), [1], { :default => RDBI::Type.filterlist() })
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

  def test_03_fetch
    res = mock_result
    assert_equal([[-1,0,1]], res.fetch)
    assert_equal(1, get_index(res))

    assert_equal(generate_data[1..9], res.fetch(9))
    assert_equal(10, get_index(res))
    assert_equal([], res.fetch)

    res = mock_result
    assert_equal(generate_data, res.fetch(:all))

    res = mock_result
    res.fetch
    assert_equal(generate_data, res.fetch(:all))
    assert_equal(1, get_index(res))
    assert_equal(generate_data[1..9], res.fetch(:rest))
    assert_equal(10, get_index(res))
  end

  def test_04_finish
    res = mock_result
    res.finish

    guts = get_guts(res)

    guts.values.each { |value| assert_nil(value) } 
  end

  def test_05_enumerable_and_index_predicates
    res = mock_result

    assert(res.has_data?)
    assert(res.has_data)

    assert(res.complete?)
    assert(res.complete)

    expected = generate_data
    
    res.each_with_index do |x, i|
      assert_equal(expected[i], x)
    end
    
    assert(res.complete?)
    assert(res.complete)
    assert(res.has_data?)
    assert(res.has_data)
    assert(res.eof?)
    assert(res.eof)
    assert(!res.more?)
    assert(!res.more)
  end

  def test_06_as
    res = mock_result
    res.as(RDBI::Result::Driver::CSV)
    assert_equal(
      "-1,0,1\n",
      res.fetch(1)
    )

    assert_equal(
      "0,1,2\n1,2,3\n2,3,4\n3,4,5\n4,5,6\n5,6,7\n6,7,8\n7,8,9\n8,9,10\n",
      res.fetch(:rest)
    )

    assert_equal(
      "-1,0,1\n0,1,2\n1,2,3\n2,3,4\n3,4,5\n4,5,6\n5,6,7\n6,7,8\n7,8,9\n8,9,10\n",
      res.fetch(:all)
    )

    # XXX reset intentionally.
    res.as(:Array)
    assert_equal([[-1, 0, 1]], res.fetch(1))

    res.rewind

    assert_equal(
      "-1,0,1\n",
      res.fetch(1, RDBI::Result::Driver::CSV)
    )

    # XXX this is intentional behavior, because I'm lazy. maybe we'll change it.
    assert_equal(
      "-1,0,1\n0,1,2\n1,2,3\n2,3,4\n3,4,5\n4,5,6\n5,6,7\n6,7,8\n7,8,9\n8,9,10\n",
      res.fetch(:rest, RDBI::Result::Driver::CSV)
    )

    assert_equal(
      "-1,0,1\n0,1,2\n1,2,3\n2,3,4\n3,4,5\n4,5,6\n5,6,7\n6,7,8\n7,8,9\n8,9,10\n",
      res.fetch(:all, RDBI::Result::Driver::CSV)
    )
  end

  def test_07_as_struct
    res = mock_result
    res.as(RDBI::Result::Driver::Struct)

    results = res.fetch(1)
    assert_kind_of(Array, results)
    assert(results[0].kind_of?(::Struct)) 

    hash = results[0]

    assert_raises(NameError) { hash[:test] = "something" }
    assert_raises(NameError) { hash['test'] = "something" }
    assert_raises(NoMethodError) { hash.test = "something" }

    assert_equal(-1, hash.zero)
    assert_equal(0, hash.one)
    assert_equal(1, hash.two)

    hash = res.fetch(1)[0]

    assert_equal(0, hash.zero)
    assert_equal(1, hash.one)
    assert_equal(2, hash.two)
  end

  def test_08_reload
    res = mock_result 

    assert_equal([-1, 0, 1], res.fetch(1)[0])
    assert_equal(1, res.instance_eval { @index })
    assert_equal(10, res.rows)
    assert_equal([:zero, :one, :two], res.schema.columns.map(&:name))

    res.reload

    # this will actually come back from the Mock driver, which will be
    # completely different.  not the best test, but it gets the job done.
    assert_equal(%W[10], res.fetch(1)[0])
    assert_equal(1, res.instance_eval { @index })
    assert_equal(5, res.rows)
    assert_equal((0..9).to_a, res.schema.columns.map(&:name))
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
