require 'helper'

class TestTypes < Test::Unit::TestCase
  def setup
    @out_types = RDBI::Type.create_type_hash(RDBI::Type::Out)
    @in_types  = RDBI::Type.create_type_hash(RDBI::Type::In)
  end

  def test_01_basic
    assert_respond_to(RDBI::Type, :create_type_hash)

    assert(@out_types)
    assert_kind_of(Hash, @out_types)
    assert(@out_types.keys.include?(:integer))
    assert(@out_types.keys.include?(:decimal))
    assert(@out_types.keys.include?(:datetime))
    assert(@out_types.keys.include?(:default))
    assert_respond_to(RDBI::Type::Out, :convert)

    assert(@in_types)
    assert_kind_of(Hash, @in_types)
    assert(@in_types.keys.include?(Integer))
    assert(@in_types.keys.include?(BigDecimal))
    assert(@in_types.keys.include?(DateTime))
    assert(@in_types.keys.include?(:default))
    assert_respond_to(RDBI::Type::In, :convert)
  end

  def test_02_out_basic_convert
    assert_equal(1,   out_convert("1", tcc(:integer), @out_types))
    assert_equal(nil, out_convert(nil, tcc(:integer), @out_types))

    assert_equal(BigDecimal("1.0"), out_convert("1.0", tcc(:decimal), @out_types))
    assert_equal(nil,               out_convert(nil, tcc(:decimal), @out_types))

    assert_kind_of(DateTime, out_convert(DateTime.now, tcc(:default), @out_types))
    assert_kind_of(Float,    out_convert(1.0, tcc(:default), @out_types))
  end

  def test_03_out_datetime_convert
    format = RDBI::Type::DEFAULT_STRFTIME_FILTER
    dt = DateTime.now

    conv      = out_convert(dt, tcc(:datetime), @out_types).strftime(format)
    formatted = dt.strftime(format)

    assert_equal(formatted, conv)
  end

  def test_04_in_basic_convert
    assert_equal("1", in_convert(1, @in_types))
    assert_equal("1", in_convert(Integer("1"), @in_types))
    assert_equal("1.0", in_convert(1.0, @in_types))
    assert_equal("1.0", in_convert(BigDecimal("1.0"), @in_types))
    assert_equal("artsy", in_convert("artsy", @in_types))
    assert_equal(nil, in_convert(nil, @in_types))
  end

  def test_05_in_datetime_convert
    format = RDBI::Type::DEFAULT_STRFTIME_FILTER
    dt = DateTime.now

    conv      = in_convert(dt, @in_types)
    formatted = dt.strftime(format)

    assert_equal(formatted, conv)
  end

  def test_06_out_integration
    dt = DateTime.now
    dbh = mock_connect 
    sth = dbh.prepare("select * from foo")
    sth.set_schema = RDBI::Schema.new(
      [
        RDBI::Column.new(:foo, :integer, :integer), 
        RDBI::Column.new(:bar, :datetime, :datetime),
        RDBI::Column.new(:quux, :varchar, :string),
        RDBI::Column.new(:baz, :decimal, :decimal)
      ]
    )

    sth.result = [["1", dt.strftime(RDBI::Type::DEFAULT_STRFTIME_FILTER), "hello, world!", "1.0"]]

    res = sth.execute().fetch[0]

    # we can't test datetime objects directly... because datetime is fail.
    # so, what we do here is compare each result individually.
    assert_equal(1, res[0])
    assert_equal(dt.strftime(RDBI::Type::DEFAULT_STRFTIME_FILTER), res[1].strftime(RDBI::Type::DEFAULT_STRFTIME_FILTER))
    assert_equal("hello, world!", res[2])
    assert_equal(BigDecimal("1.0"), res[3])
  end
end
