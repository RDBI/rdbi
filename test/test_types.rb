require 'helper'

class TestTypes < Test::Unit::TestCase
  def setup
    @out_types = RDBI::Type::Out.create_type_hash
  end

  def test_01_basic
    assert(@out_types)
    assert_kind_of(Hash, @out_types)
    assert(@out_types.keys.include?(:integer))
    assert(@out_types.keys.include?(:decimal))
    assert(@out_types.keys.include?(:default))
    assert_respond_to(RDBI::Type::Out, :create_type_hash)
    assert_respond_to(RDBI::Type::Out, :convert)
  end

  def test_02_basic_convert
    assert_equal(1,   convert("1", tcc(:integer), @out_types))
    assert_equal(nil, convert(nil, tcc(:integer), @out_types))

    assert_equal(BigDecimal("1.0"), convert("1.0", tcc(:decimal), @out_types))
    assert_equal(nil,               convert(nil, tcc(:decimal), @out_types))

    assert_kind_of(DateTime, convert(DateTime.now, tcc(:default), @out_types))
    assert_kind_of(Float,    convert(1.0, tcc(:default), @out_types))
  end

  def test_03_datetime_convert
    format = "%Y-%m-%d %H:%M:%S %z"
    dt = DateTime.now

    conv      = convert(dt, tcc(:datetime), @out_types).strftime(format)
    formatted = dt.strftime(format)

    assert_equal(formatted, conv)
  end
end
