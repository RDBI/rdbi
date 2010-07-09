require 'helper'

class TestUtil < Test::Unit::TestCase
  def test_01_exists
    assert(RDBI::Util)
  end

  def test_02_optional_require
    assert_raises(
      LoadError.new("The 'fart' gem is required to use this driver. Please install it.")
    ) { RDBI::Util.optional_require('fart') }

    RDBI::Util.optional_require('ostruct')
  end

  def test_03_class_from_class_or_symbol
    assert_raises(ArgumentError.new("Invalid argument for driver name; must be Class, or a Symbol or String identifying the Class, and the driver Class must have been loaded")) do
      RDBI::Util.class_from_class_or_symbol(1, RDBI)
    end

    assert_equal(
      RDBI::Driver::Mock,
      RDBI::Util.class_from_class_or_symbol(RDBI::Driver::Mock, RDBI::Driver)
    )

    assert_equal(
      RDBI::Driver::Mock,
      RDBI::Util.class_from_class_or_symbol(:Mock, RDBI::Driver)
    )

    assert_equal(
      RDBI::Driver::Mock,
      RDBI::Util.class_from_class_or_symbol('Mock', RDBI::Driver)
    )
  end

  def test_04_key_hash_as_symbols
    hash  = { "one" => 1, "two" => 2 }
    hash2 = { :one => 1, :two => 2 }

    assert_equal(
      hash2,
      RDBI::Util.key_hash_as_symbols(hash)
    )

    assert_equal(
      hash2,
      RDBI::Util.key_hash_as_symbols(hash2)
    )
  end

  def test_05_deep_copy
    arr = %w(a b c d e f)
    arr2 = RDBI::Util.deep_copy(arr)
    assert_equal arr, arr2
    arr.zip(arr2).each do |left, right|
      assert_equal left, right
      assert_not_equal left.object_id, right.object_id
    end
  end
end
