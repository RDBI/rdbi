require 'helper'

class TestTypes < Test::Unit::TestCase
  def setup
    @types = RDBI::Type.create_type_hash
  end

  def test_01_basic
    assert(@types)
    assert_kind_of(HashPipe, @types)
    assert(@types.keys.include?(:integer))
    assert(@types.keys.include?(:decimal))
    assert(@types.keys.include?(:default))
    assert_respond_to(RDBI::Type, :create_type_hash)
    assert_respond_to(RDBI::Type, :convert)
  end

  def test_02_basic_convert
  end
end
