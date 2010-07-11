#
# RDBI::Result encapsulates results from a statement.
#
# Results in RDBI::Result are row-oriented and may be transformable by Result
# Drivers (RDBI::Result::Driver). They are fetched as a unit or in order.
#
# The RDBI::Result API is deliberately architected to loosely resemble that of
# IO or File.
#
# == Just give me the data!
#
# Have a peek at RDBI::Result#fetch.
#
# == Result Counts
#
# Multiple kinds of counts are represented in each result:
#
# * A count of the results provided
# * A count of the affected rows.
#
# To elaborate, the "affected rows" is a count of rows that were altered by the
# statement from a DML result such as +INSERT+ or +UPDATE+. In some cases,
# statements will both alter rows and yield results, which is why this value is
# not switched depending on the kind of statement. 
#
# == Result Drivers
#
# Result drivers are subclasses of RDBI::Result::Driver that take the result as
# input and yield a transformed input: data structures such a hashes, or even
# wilder results such as CSV or JSON or YAML. Given the ability to sanely
# transform row-oriented input, result driver effectively have the power to do
# anything.
#
# Accessing result drivers is as easy as using a secondary form of
# RDBI::Result#fetch or more explicitly with the RDBI::Result#as call.
#
class RDBI::Result
  extend MethLab
  include Enumerable

  # The RDBI::Schema structure associated with this result.
  attr_reader :schema

  # The RDBI::Statement that yielded this result.
  attr_reader :sth

  # The RDBI::Result::Driver currently associated with this Result.
  attr_reader :driver

  # The count of results (see RDBI::Result main documentation)
  attr_reader :result_count

  # The count of affected rows by a DML statement (see RDBI::Result main documentation)
  attr_reader :affected_count

  # The mapping of types for each positional argument in the Result.
  attr_reader :type_hash

  # The binds used in the statement that yielded this Result.
  attr_reader :binds

  # FIXME async
  inline(:complete, :complete?) { true }

  ##
  # :attr_reader: eof
  #
  # Are we at the end of the results?
  
  ##
  # :attr_reader: eof?
  #
  # Are we at the end of the results?
  inline(:eof, :eof?)           { @index >= @data.size }

  ##
  # :attr_reader: more
  #
  # Do we have more input available?
  
  ##
  # :attr_reader: more?
  #
  # Do we have more input available?
  inline(:more, :more?)         { @index  < @data.size }

  ##
  # :attr_reader: has_data
  #
  # Does this result have data?
  
  ##
  # :attr_reader: has_data?
  #
  # Does this result have data?
  inline(:has_data, :has_data?) { @data.size > 0 }

  #
  # Creates a new RDBI::Result. Please refer to RDBI::Statement#new_execution
  # for instructions on how this is typically use and the contents passed to
  # the constructor.
  #
  def initialize(sth, binds, data, schema, type_hash, affected_count=0)
    @schema         = schema
    @data           = data
    @result_count   = data.size
    @affected_count = affected_count
    @sth            = sth
    @binds          = binds
    @type_hash      = type_hash
    @index          = 0
    @mutex          = Mutex.new
    @driver         = RDBI::Result::Driver::Array
    @fetch_handle   = nil
    as(@driver)
  end

  #
  # Reload the result. This will:
  #
  # * Execute the statement that yielded this result again, with the original binds 
  # * Replace the results and other attributes with the new results.
  #
  def reload
    res = @sth.execute(*@binds)
    @data           = res.instance_variable_get(:@data)
    @type_hash      = res.instance_variable_get(:@type_hash)
    @schema         = res.instance_variable_get(:@schema)
    @result_count   = res.instance_variable_get(:@result_count)
    @affected_count = res.instance_variable_get(:@affected_count)
    @index          = 0
  end

  #
  # Iterator for Enumerable methods. Yields a row at a time.
  #
  def each
    yield(fetch[0]) while more?
  end

  #
  # Reset the index.
  #
  def rewind
    @index = 0
  end

  #
  # :call-seq: 
  #   as(String)
  #   as(Symbol)
  #   as(Class)
  #   as([Class, String, or Symbol], *driver_arguments)
  # 
  # Replace the Result Driver. See RDBI::Result's main docs and
  # RDBI::Result::Driver for more information on Result Drivers.
  #
  # You may pass:
  #
  # * A Symbol or String which is shorthand for loading from the
  #   RDBI::Result::Driver namespace -- for example: "CSV" will result in the
  #   class RDBI::Result::Driver::CSV.
  # * A full class name.
  #
  # There are no naming requirements; the String/Symbol form is just shorthand
  # for convention.
  #
  # Any additional arguments will be passed to the driver's constructor.
  #
  def as(driver_klass, *args)

    driver_klass  = RDBI::Util.class_from_class_or_symbol(driver_klass, RDBI::Result::Driver)

    @driver       = driver_klass
    @fetch_handle = driver_klass.new(self, *args)
  end

  #
  # :call-seq:
  #   fetch()
  #   fetch(Integer)
  #   fetch(:first)
  #   fetch(:last)
  #   fetch(:all)
  #   fetch(:rest)
  #   fetch(amount, [Class, String, or Symbol], *driver_arguments)
  #
  # fetch is the way people will typically interact with this class. It yields
  # some or all of the results depending on the arguments given. Additionally,
  # it can be supplemented with the arguments passed to RDBI::Result#as to
  # one-off select a result driver.
  #
  # The initial argument can be none or one of many options:
  #
  # * An Integer n requests n rows from the result and increments the index.
  # * No argument uses an Integer count of 1.
  # * :first yields the first row of the result, regardless of the index. 
  # * :last yields the last row of the result, regardless of the index.
  # * :all yields the whole set of rows, regardless of the index.
  # * :rest yields all the items that have not been fetched, determined by the index.
  #
  # == The index
  #
  # I bet you're wondering what that is now, right? Well, the index is
  # essentially a running row count that is altered by certain fetch
  # operations. This makes sequential fetches much simpler.
  #
  # Items that do not use the index do not effect it.
  #
  # Result Drivers will always rewind the index, as this implicates a "point of
  # no return" state change. You may always return to the original driver you
  # were using, but the index position will be lost.
  #
  def fetch(row_count=1, driver_klass=nil, *args)
    if driver_klass
      as(driver_klass, *args)
    end

    @fetch_handle.fetch(row_count)
  end

  alias read fetch

  # 
  # raw_fetch is a straight array fetch without driver interaction. If you
  # think you need this, please still read the fetch documentation as there is
  # a considerable amount of overlap.
  #
  # This is generally used by Result Drivers to transform results.
  #
  def raw_fetch(row_count)
    final_res = case row_count
                when :all
                  @data
                when :rest
                  oindex, @index = @index, @data.size
                  @data[oindex, @index]
                when :first
                  @data.first
                when :last
                  @data[-1]
                else
                  res = @data[@index, row_count]
                  @index += row_count
                  res
                end
    RDBI::Util.deep_copy(final_res)
  end

  #
  # This call finishes the result and the RDBI::Statement handle, scheduling
  # any unpreserved data for garbage collection.
  #
  def finish
    @sth.finish
    @data   = nil
    @sth    = nil
    @driver = nil
    @binds  = nil
    @schema = nil
    @index  = nil
  end
end

#
# A result driver is a transformative element for RDBI::Result. Its design
# could be loosely described as a "fancy decorator".
#
# Usage and purpose is covered in the main RDBI::Result documentation. This
# section will largely serve the purpose of helping those who wish to implement
# result drivers themselves.
#
# == Creating a Result Driver
#
# A result driver typically inherits from RDBI::Result::Driver and implements
# at least one method: +fetch+.
#
# This fetch is not RDBI::Result#fetch, and doesn't have the same call
# semantics. Instead, it takes a single argument, the +row_count+, and
# typically passes that to RDBI::Result#raw_fetch to get results to process. It
# then returns the data transformed.
#
# RDBI::Result::Driver additionally provides two methods, convert_row and
# convert_item, which leverage RDBI's type conversion facility (see RDBI::Type)
# to assist in type conversion. For performance reasons, RDBI chooses to
# convert on request instead of preemptively, so <b>it is the driver implementor's
# job to do any conversion</b>.
#
# If you wish to implement a constructor in your class, please see
# RDBI::Result::Driver.new.
#
class RDBI::Result::Driver

  #
  # Result driver constructor. This is the logic that associates the result
  # driver for decoration over the result; if you wish to override this method,
  # please call +super+ before performing your own operations.
  #
  def initialize(result, *args)
    @result = result
    @result.rewind
  end

  #
  # Fetch the result with any transformations. The default is to present the
  # type converted array.
  #
  def fetch(row_count)
    (@result.raw_fetch(row_count) || []).enum_for.with_index.map do |item, i|
      case row_count
      when :first, :last
        convert_item(item, @result.schema.columns[i])
      else
        convert_row(item)
      end
    end
  end

  # convert an entire row of data with the specified result map (see
  # RDBI::Type)
  def convert_row(row)
    newrow = []
    row.each_with_index do |x, i|
      newrow.push(convert_item(x, @result.schema.columns[i]))
    end
    return newrow
  end

  # convert a single item (row element) with the specified result map.
  def convert_item(item, column)
    RDBI::Type::Out.convert(item, column, @result.type_hash)
  end
end

#
# This is the standard Array driver. If you are familiar with the typical
# results of a database layer similar to RDBI, these results should be very
# familiar.
#
# If you wish for named accessors, please see RDBI::Result::Driver::Struct.
#
class RDBI::Result::Driver::Array < RDBI::Result::Driver
end

#
# This driver yields CSV:
#
#   dbh.execute("select foo, bar from my_table").fetch(:first, :CSV)
#
# Yields the contents of columns foo and bar in CSV format (a String).
#
# The +fastercsv+ gem on 1.8 is used, which is the canonical +csv+ library on
# 1.9. If you are using Ruby 1.8 and do not have this gem available and try to
# use this driver, the code will abort during driver construction. 
#
class RDBI::Result::Driver::CSV < RDBI::Result::Driver
  def initialize(result, *args)
    super
    if RUBY_VERSION =~ /^1.8/
      RDBI::Util.optional_require('fastercsv')
    else
      require 'csv'
    end
    # FIXME columns from schema deal maybe?
  end

  def fetch(row_count)
    csv_string = ""
    @result.raw_fetch(row_count).each do |row|
      csv_string << row.to_csv
    end
    return csv_string
  end
end

# 
# Yields Struct objects instead of arrays for the rows. What this means is that
# you will recieve a single array of Structs, each struct representing a row of
# the database.
#
# example:
#
#   results = dbh.execute("select foo, bar from my_table").fetch(:all, :Struct)
#
#   results[0].foo        # first row, foo column
#   results[10].bar       # 11th row, bar column
#
class RDBI::Result::Driver::Struct < RDBI::Result::Driver
  def initialize(result, *args)
    super
  end

  def fetch(row_count)
    structs = []
    column_names = @result.schema.columns.map(&:name)

    klass = ::Struct.new(*column_names)

    @result.raw_fetch(row_count).each do |row|
      row = convert_row(row)
      struct = klass.new(*row)
      structs.push(struct)
    end

    return structs
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
