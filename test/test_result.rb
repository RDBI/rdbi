require 'helper'

class TestResult < Test::Unit::TestCase
  def setup
    @dbh = mock_connect 
  end

  def teardown
    @dbh.disconnect
  end

  def generate_data
    RDBI::Driver::Mock::Cursor.new((0..9).to_a.map { |x| [x-1, x, x+1] })
  end
  
  def mock_result
    names = [:zero, :one, :two]
    res = RDBI::Result.new(
      @dbh.prepare("foo"), 
      [1], 
      generate_data, 
      RDBI::Schema.new((0..2).to_a.map { |x| RDBI::Column.new(names[x], :integer, :default) }), 
      { :default => RDBI::Type.filterlist() }
    )
  end

  def mock_empty_result
    names = [:zero, :one, :two]
    res = RDBI::Result.new(
      @dbh.prepare("foo"), 
      [1], 
      RDBI::Driver::Mock::Cursor.new([]), 
      RDBI::Schema.new((0..2).to_a.map { |x| RDBI::Column.new(names[x], :integer, :default) }), 
      { :default => RDBI::Type.filterlist() }
    )
  end

  def get_index(res)
    cursor = get_guts(res)[:data]
    cursor.instance_variable_get("@index") || res.instance_variable_get(:@index)
  end

  def get_guts(res)
    h = { }
    %W[schema binds sth data].collect(&:to_sym).each do |sym|
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
    res.sth.finish

    assert_kind_of(RDBI::Schema, guts[:schema])
    assert_kind_of(RDBI::Schema, res.schema)
    assert_equal(res.schema, guts[:schema])

    assert_kind_of(Array, guts[:binds])
    assert_equal(res.binds, guts[:binds])
    assert_equal([1], guts[:binds])
  end

  def test_02_responds
    res = mock_result

    %W[
      schema
      sth
      driver
      result_count
      affected_count
      complete
      complete?
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

    res.sth.finish
  end

  def test_03_fetch
    res = mock_result
    assert_equal([[-1,0,1]], res.fetch)
    assert_equal(1, get_index(res))

    assert_equal(generate_data[1..9], res.fetch(9))
    assert_equal(10, get_index(res))
    assert_equal([], res.fetch)
    res.sth.finish

    res = mock_result
    assert_equal(generate_data.all, res.fetch(:all))
    res.sth.finish

    res = mock_result
    res.fetch
    assert_equal(generate_data.all, res.fetch(:all))
    assert_equal(1, get_index(res))
    assert_equal(generate_data[1..9], res.fetch(:rest))
    assert_equal(10, get_index(res))

    assert_equal(generate_data[0], res.fetch(:first))
    assert_equal(generate_data[-1], res.fetch(:last))
    assert_equal(generate_data[0], res.first)
    assert_equal(generate_data[-1], res.last)

    res.sth.finish
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
    res.sth.finish
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
    res.sth.finish
    
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
    res.sth.finish
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
    
    hash = res.fetch(:first)
   
    assert_equal(-1, hash.zero)
    assert_equal(0, hash.one)
    assert_equal(1, hash.two)
    
    res.sth.finish

    res = mock_empty_result

    hash = res.fetch(:first, :Struct)
    assert_nil(hash)
    res.sth.finish
  end

  def test_08_reload
    res = mock_result 

    assert_equal([-1, 0, 1], res.fetch(1)[0])
    assert_equal(10, res.result_count)
    assert_equal([:zero, :one, :two], res.schema.columns.map(&:name))

    res.reload

    # this will actually come back from the Mock driver, which will be
    # completely different.  not the best test, but it gets the job done.
    assert_equal(%W[10], res.fetch(1)[0])
    assert_equal(5, res.result_count)
    assert_equal((0..9).to_a, res.schema.columns.map(&:name))
    res.finish
  end

  def test_09_insert_results
    dbh = mock_connect
    sth = dbh.prepare('insert into blah (foo, bar) values (?, ?)')
    sth.result = [[1,2,3], [1,2,3]]
    sth.affected_count = 10

    res = sth.execute(1,2)

    assert_equal(16, res.affected_count)
    assert_equal(2,  res.result_count)
    sth.finish
  end

  def test_10_null_results
    res = RDBI::Result.new(@dbh.prepare("foo"), [1], RDBI::Driver::Mock::Cursor.new([]), [], 0)
    assert_equal(nil, res.fetch(:first))
    assert_equal(nil, res.fetch(:last))
    assert_equal([], res.fetch(:all))
    assert_equal([], res.fetch(:rest))
    assert_equal([], res.fetch(1))
    res.sth.finish
  end

  def test_11_rewindable_results
    @dbh.rewindable_result = true
    res = RDBI::Result.new(@dbh.prepare("foo"), [1], RDBI::Driver::Mock::Cursor.new([]), [], 0)

    res.sth.rewindable_result = false
    assert_raises(StandardError) { res.rewind }
    res.sth.rewindable_result = true
    res.reload
    res.rewind
  end

  def test_12_as_yaml
    res = mock_result
    require 'yaml'

    assert_equal(
      [ 
        {:zero=>-1, :one=>0, :two=>1},
        {:zero=>0, :one=>1, :two=>2},
        {:zero=>1, :one=>2, :two=>3},
        {:zero=>2, :one=>3, :two=>4},
        {:zero=>3, :one=>4, :two=>5},
        {:zero=>4, :one=>5, :two=>6},
        {:zero=>5, :one=>6, :two=>7},
        {:zero=>6, :one=>7, :two=>8},
        {:zero=>7, :one=>8, :two=>9},
        {:zero=>8, :one=>9, :two=>10}
      ],
      YAML.load(res.as(:YAML).fetch(:all))
    )

    assert_equal({:zero=>-1, :one=>0, :two=>1}, YAML.load(res.as(:YAML).first))
    assert_equal({:zero=>8, :one=>9, :two=>10}, YAML.load(res.as(:YAML).last))
  end

  def test_13_enumerable_as
    # 'master' dab6270 branch (0.9.1+) returned a Result::Driver for as()

    res = mock_result

    i = -1
    # Mock result set is:
    #
    #   ZERO  ONE  TWO
    #   ====  ===  ===
    #    -1    0    1
    #     0    1    2
    #     1    2    3
    #         ...
    #     8    9   10
    #
    res.as(:Struct).each do |row|
      assert_kind_of(::Struct, row)
      assert_equal([i, i+1, i+2], [row.zero, row.one, row.two])
      i += 1
    end
    res.sth.finish
  end

  def test_14_results_driven_struct
    # 'master' dab6270 branch (0.9.1+) returned 'raw' rows for #each,
    # #first and #last

    res = mock_result

    res.as(:Struct)
    row = res.first # does not advance underlying index
    assert_kind_of(::Struct, row)
    assert_equal([-1, 0, 1], [row.zero, row.one, row.two])

    res.each do |r|
      assert_kind_of(::Struct, r)
      assert_equal([-1, 0, 1], [r.zero, r.one, r.two])
      break # Just one row, thank you
    end

    row = res.last
    assert_kind_of(::Struct, row)
    assert_equal([8, 9, 10], [row.zero, row.one, row.two])

    res.sth.finish
  end

  def test_15_results_driven_csv
    # 'master' 20917a3 branch (pilcrow/result-as) didn't handle
    # eof properly for result drivers that didn't return sets of
    # rows as an array of rows

    res = mock_result

    res.as(:CSV)
    row = res.first # does not advance underlying index
    assert_equal("-1,0,1\n", row)

    res.each do |r|
      assert_equal("-1,0,1\n", r)
      break # Just one row, thank you
    end

    row = res.last
    assert_equal("8,9,10\n", row)

    res.sth.finish
  end

  def test_16_results_driven_yaml
    # As for test_15, but with YAML
    # 'master' 20917a3 branch (pilcrow/result-as) didn't handle
    # eof properly for result drivers that didn't return sets of
    # rows as an array of rows

    res = mock_result

    res.as(:YAML)
    row = res.first # does not advance underlying index
    assert_equal({:zero=>-1, :one=>0, :two=>1}, YAML.load(row))

    res.each do |r|
      assert_equal({:zero=>-1, :one=>0, :two=>1}, YAML.load(r))
      break # Just one row, thank you
    end

    row = res.last
    assert_equal({:zero=>8, :one=>9, :two=>10}, YAML.load(row))

    res.sth.finish
  end

end

# vim: syntax=ruby ts=2 et sw=2 sts=2
