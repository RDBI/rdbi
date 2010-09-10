require 'typelib'
require 'typelib/canned'

#
# == RDBI::Type -- manage types going to and coming from your database.
#
# RDBI::Type consists of:
#
# * Checks and Conversions (facilitated by TypeLib) for ruby -> database and
#   database -> ruby
# * Mappings for Input (Ruby -> DB) and Output (DB -> Ruby) conversions based
#   on type.
# * Convenience methods for TypeLib and creating new mappings.
#
# == How does it all work?
#
# RDBI::Type leverages +TypeLib+ which is a filter chaining system, one which
# you'll wish to read the documentation for to understand some of the concepts
# here. 
#
# === A conversion follows these steps:
#
# * Metadata on the type (more below) is located and used to reference a
#   TypeLib::FilterList which contains the TypeLib::Filters (which in turn
#   consist of a +Check+ and +Conversion+ proc) which will process your data.
# * Data is passed to the FilterList and it is executed, following each filter
#   in turn and following any conversion passing checks request. This may very
#   well mean that no checks pass and therefore your original data is returned.
# * After processing, the data is yielded back to you for further processing
#   (or a subsystem such as RDBI::Result#fetch and result drivers that take
#   advantage of said data)
#
# === How is metadata located?
#
# It's important first to briefly describe how RDBI terms database I/O:
#
# * Binds going to the database proper are called 'input'.
# * Data coming from the database is called 'output'.
#
# Mappings are keyed by type metadata and thusly are typed as:
#
# * Input types are the native class of the type.
# * Output types are a symbol that represents the database type. These type
#   names are provided by RDBI::Column via RDBI::Schema in the response from an
#   execution. See RDBI::Statement#new_execution and RDBI::Column#ruby_type.
#
# Note that in the latter case these database types are effectively normalized,
# e.g., 'timestamp with timezone' in postgres is just +:timestamp+. You will
# want to read the mappings in the source to get a full listing of what's
# supported by default.
#
# Each map will also contain +:default+, which is what is used when a proper
# lookup fails, as a fallback.
#
# === Ok, so how do I use these maps?
#
# RDBI::Type.create_type_hash is a helper to duplicate the default maps and
# return them. If you don't wish to use the default maps at all, just a plain
# old +Hash+ following the semantics above will work.
#
# To perform conversions, look at RDBI::Type::In::convert and
# RDBI::Type::Out::convert.
# 
module RDBI::Type
  # A filter format to assist the conversions of DateTime objects.
  DEFAULT_STRFTIME_FILTER = "%Y-%m-%d %H:%M:%S %z"

  # Module for canned checks that are unique to RDBI. Includes the canned
  # checks from TypeLib.
  module Checks
    include TypeLib::Canned::Checks

    IS_NULL       = proc { |obj| obj.nil? }
    IS_BIGDECIMAL = proc { |obj| obj.kind_of?(BigDecimal) }
    IS_DATETIME   = proc { |obj| obj.kind_of?(DateTime) }
    IS_BOOLEAN    = proc { |obj| obj.kind_of?(TrueClass) or obj.kind_of?(FalseClass) }

    STR_IS_BOOLEAN = proc { |obj| obj.kind_of?(String) and obj =~ /^(t(rue)?|f(alse)?|1|0)$/i }
  end

  # Module for canned conversions that are unique to RDBI. Includes the canned
  # conversions from TypeLib.
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

  # Canned +TypeLib::Filter+ objects unique to RDBI to facilitate certain
  # conversions. Includes TypeLib's canned filters.
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

  # Shorthand for creating a new +TypeLib::FilterList+.
  def self.filterlist(*ary)
    TypeLib::FilterList.new([Filters::NULL, *ary])
  end

  # Shorthand to duplicate the +DEFAULTS+ hash from a module. Most frequently
  # used to get a copy of the RDBI::Type::In and RDBI::Type::Out type maps.
  def self.create_type_hash(klass)
    hash = { }
    orig = klass::DEFAULTS
    orig.keys.each do |key|
      flist = filterlist()
      orig[key].each do |filter|
        flist << filter
      end
      hash[key] = flist
    end

    return hash
  end

  #
  # The default output type map. As explained in RDBI::Type, these are keyed by
  # symbol and are loosely related to the type, and are compared against the
  # proper RDBI::Column object to figure out which filter to call.
  #
  module Out
    DEFAULTS = {
      :integer     => RDBI::Type.filterlist(Filters::STR_TO_INT),
      :decimal     => RDBI::Type.filterlist(Filters::STR_TO_DEC),
      :datetime    => RDBI::Type.filterlist(TypeLib::Canned.build_strptime_filter(DEFAULT_STRFTIME_FILTER)),
      :timestamp   => RDBI::Type.filterlist(TypeLib::Canned.build_strptime_filter(DEFAULT_STRFTIME_FILTER)),
      :boolean     => RDBI::Type.filterlist(Filters::TO_BOOLEAN),
      :default     => RDBI::Type.filterlist()
    }

    #
    # Perform a conversion. Accepts the object to convert, a RDBI::Column
    # object, and a type map (a +Hash+).
    #
    def self.convert(obj, column, type_hash)
      fl = type_hash[column.ruby_type]

      unless fl
        fl = type_hash[:default]
      end

      fl.execute(obj)
    end
  end

  #
  # The default input type map. As explained in RDBI::Type, these are keyed by
  # the Ruby type with the exception of +:default+ which is a fallback
  # conversion. RDBI::Statement subclassers will normally provide this object
  # via +@input_type_map+ at construction time.
  #
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

    #
    # Perform a conversion. Accepts the object to convert and a type map (a
    # +Hash+).
    #
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
