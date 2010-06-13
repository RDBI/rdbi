require 'typelib'
require 'typelib/canned'

module RDBI
  module Type

    DEFAULT_STRFTIME_FILTER = "%Y-%m-%d %H:%M:%S %z"

    module Checks
      include TypeLib::Canned::Checks

      IS_NULL       = proc { |obj| obj.nil? }
      IS_BIGDECIMAL = proc { |obj| obj.kind_of?(BigDecimal) }
      IS_DATETIME   = proc { |obj| obj.kind_of?(DateTime) }
    end

    module Conversions
      include TypeLib::Canned::Conversions

      TO_NULL            = proc { |obj| nil }
      TO_STRING_DECIMAL  = proc { |obj| obj.to_s('F') }
      TO_STRING_DATETIME = proc { |obj| obj.strftime(DEFAULT_STRFTIME_FILTER) }
    end

    module Filters
      include TypeLib::Canned::Filters

      NULL           = TypeLib::Filter.new(Checks::IS_NULL,       Conversions::TO_NULL)
      FROM_INTEGER   = TypeLib::Filter.new(Checks::IS_INTEGER,    Conversions::TO_STRING)
      FROM_NUMERIC   = TypeLib::Filter.new(Checks::IS_NUMERIC,    Conversions::TO_STRING)
      FROM_DECIMAL   = TypeLib::Filter.new(Checks::IS_BIGDECIMAL, Conversions::TO_STRING_DECIMAL)
      FROM_DATETIME  = TypeLib::Filter.new(Checks::IS_DATETIME,   Conversions::TO_STRING_DATETIME)
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
        :integer  => Type.filterlist(Filters::STR_TO_INT),
        :decimal  => Type.filterlist(Filters::STR_TO_DEC),
        :datetime => Type.filterlist(TypeLib::Canned.build_strptime_filter(DEFAULT_STRFTIME_FILTER)),
        :default  => Type.filterlist()
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
        Integer    => Type.filterlist(Filters::FROM_INTEGER),
        Fixnum     => Type.filterlist(Filters::FROM_INTEGER),
        Float      => Type.filterlist(Filters::FROM_NUMERIC),
        BigDecimal => Type.filterlist(Filters::FROM_DECIMAL),
        DateTime   => Type.filterlist(Filters::FROM_DATETIME),
        :default   => Type.filterlist()
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
end
