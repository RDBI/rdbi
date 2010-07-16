require 'typelib'
require 'typelib/canned'

module RDBI::Type
  DEFAULT_STRFTIME_FILTER = "%Y-%m-%d %H:%M:%S %z"

  module Checks
    include TypeLib::Canned::Checks

    IS_NULL       = proc { |obj| obj.nil? }
    IS_BIGDECIMAL = proc { |obj| obj.kind_of?(BigDecimal) }
    IS_DATETIME   = proc { |obj| obj.kind_of?(DateTime) }
    IS_BOOLEAN    = proc { |obj| obj.kind_of?(TrueClass) or obj.kind_of?(FalseClass) }

    STR_IS_BOOLEAN = proc { |obj| obj.kind_of?(String) and obj =~ /^(t(rue)?|f(alse)?|1|0)$/i }
  end

  module Conversions
    include TypeLib::Canned::Conversions

    TO_NULL            = proc { |obj| nil }
    TO_STRING_DECIMAL  = proc { |obj| obj.to_s('F') }
    TO_STRING_DATETIME = proc { |obj| obj.strftime(DEFAULT_STRFTIME_FILTER) }
    TO_STRING_BOOLEAN  = proc { |obj| obj ? 'TRUE' : 'FALSE' }

    SQL_STR_TO_BOOLEAN = proc { |obj|
      case obj
        when /^(t(rue)?|1)$/i
          true
        when /^(f(alse)?|0)$/i
          false
      end
    }
  end

  module Filters
    include TypeLib::Canned::Filters

    NULL           = TypeLib::Filter.new(Checks::IS_NULL,       Conversions::TO_NULL)
    FROM_INTEGER   = TypeLib::Filter.new(Checks::IS_INTEGER,    Conversions::TO_STRING)
    FROM_NUMERIC   = TypeLib::Filter.new(Checks::IS_NUMERIC,    Conversions::TO_STRING)
    FROM_DECIMAL   = TypeLib::Filter.new(Checks::IS_BIGDECIMAL, Conversions::TO_STRING_DECIMAL)
    FROM_DATETIME  = TypeLib::Filter.new(Checks::IS_DATETIME,   Conversions::TO_STRING_DATETIME)
    FROM_BOOLEAN   = TypeLib::Filter.new(Checks::IS_BOOLEAN,    Conversions::TO_STRING_BOOLEAN)

    TO_BOOLEAN     = TypeLib::Filter.new(Checks::STR_IS_BOOLEAN, Conversions::SQL_STR_TO_BOOLEAN)
  end

  # FilterList factory shorthand
  def self.filterlist(*ary)
    TypeLib::FilterList.new([Filters::NULL, *ary])
  end

  def self.create_type_hash(klass)
    hash = klass::DEFAULTS.dup

    return hash
  end

  module Out
    DEFAULTS = {
      :integer     => RDBI::Type.filterlist(Filters::STR_TO_INT),
      :decimal     => RDBI::Type.filterlist(Filters::STR_TO_DEC),
      :datetime    => RDBI::Type.filterlist(TypeLib::Canned.build_strptime_filter(DEFAULT_STRFTIME_FILTER)),
      :timestamp   => RDBI::Type.filterlist(TypeLib::Canned.build_strptime_filter(DEFAULT_STRFTIME_FILTER)),
      :boolean     => RDBI::Type.filterlist(Filters::TO_BOOLEAN),
      :default     => RDBI::Type.filterlist()
    }

    def self.convert(obj, column, type_hash)
      fl = type_hash[column.ruby_type]

      unless fl
        fl = type_hash[:default]
      end

      fl.execute(obj)
    end
  end

  module In
    DEFAULTS = {
      Integer    => RDBI::Type.filterlist(Filters::FROM_INTEGER),
      Fixnum     => RDBI::Type.filterlist(Filters::FROM_INTEGER),
      Float      => RDBI::Type.filterlist(Filters::FROM_NUMERIC),
      BigDecimal => RDBI::Type.filterlist(Filters::FROM_DECIMAL),
      DateTime   => RDBI::Type.filterlist(Filters::FROM_DATETIME),
      TrueClass  => RDBI::Type.filterlist(Filters::FROM_BOOLEAN),
      FalseClass => RDBI::Type.filterlist(Filters::FROM_BOOLEAN),
      :default   => RDBI::Type.filterlist()
    }

    def self.convert(obj, type_hash)
      fl = type_hash[obj.class]

      unless fl
        fl = type_hash[:default]
      end

      fl.execute(obj)
    end
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
