require 'helper'

class TestTypes < Test::Unit::TestCase
  def setup
    @types = RDBI::Type.create_type_hash
  end

  def test_01_basic
    assert(@types)
    assert_kind_of(Hash, @types)
    assert(@types.keys.include?(:integer))
    assert(@types.keys.include?(:decimal))
    assert(@types.keys.include?(:default))
    assert_respond_to(RDBI::Type, :create_type_hash)
    assert_respond_to(RDBI::Type, :convert)
  end

  def test_02_basic_convert
    assert_equal(1,   convert("1", tcc(:integer), @types))
    assert_equal(nil, convert(nil, tcc(:integer), @types))

    assert_equal(BigDecimal("1.0"), convert("1.0", tcc(:decimal), @types))
    assert_equal(nil,               convert(nil, tcc(:decimal), @types))

    assert_kind_of(DateTime, convert(DateTime.now, tcc(:default), @types))
    assert_kind_of(Float,    convert(1.0, tcc(:default), @types))
  end

  def test_03_datetime_convert
    format = "%Y-%m-%d %H:%M:%S %z"
    dt = DateTime.now

    conv      = convert(dt, tcc(:datetime), @types).strftime(format)
    formatted = dt.strftime(format)

    assert_equal(formatted, conv)
  end
end
