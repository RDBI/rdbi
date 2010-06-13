require 'typelib'
require 'typelib/canned'

module RDBI
  module Type
    module Checks
      include TypeLib::Canned::Checks

      IS_NULL = proc { |obj| obj.nil? }
    end

    module Conversions
      include TypeLib::Canned::Conversions

      TO_NULL = proc { |obj| nil }
    end

    module Filters
      include TypeLib::Canned::Filters

      NULL = TypeLib::Filter.new(Checks::IS_NULL, Conversions::TO_NULL)
    end
    
    # FilterList factory shorthand
    def self.filterlist(*ary)
      TypeLib::FilterList.new([Filters::NULL, *ary])
    end

    module Out
      DEFAULTS = {
        :integer  => Type.filterlist(Filters::STR_TO_INT),
        :decimal  => Type.filterlist(Filters::STR_TO_DEC),
        :datetime => Type.filterlist(TypeLib::Canned.build_strptime_filter("%Y-%m-%d %H:%M:%S %z")),
        :default  => Type.filterlist()
      }

      def self.create_type_hash
        hash = DEFAULTS.dup

        return hash
      end

      def self.convert(obj, column, type_hash)
        fl = type_hash[column.ruby_type]

        unless fl
          fl = type_hash.default
        end

        fl.execute(obj)
      end
    end

    module In
    end
  end
end
