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
# transform row-oriented input, result drivers effectively have the power to do
# anything.
#
# Accessing result drivers is as easy as using a secondary form of
# RDBI::Result#fetch or more explicitly with the RDBI::Result#as call.
#
class RDBI::Result
  include Enumerable

  # The RDBI::Schema structure associated with this result.
  attr_reader :schema

  # The RDBI::Statement that yielded this result.
  attr_reader :sth

  # The RDBI::Result::Driver currently associated with this Result.
  attr_reader :driver

  # The mapping of types for each positional argument in the Result.
  attr_reader :type_hash

  # The binds used in the statement that yielded this Result.
  attr_reader :binds

  # See RDBI::Statement#rewindable_result.
  attr_reader :rewindable_result


  # :nodoc: FIXME async
  def complete
    true
  end

  alias complete? complete
  
  # Does this result have data?
  def has_data
    @data.size > 0
  end

  alias has_data? has_data

  #
  # Creates a new RDBI::Result. Please refer to RDBI::Statement#new_execution
  # for instructions on how this is typically used and how the contents are
  # passed to the constructor.
  #
  def initialize(sth, binds, data, schema, type_hash)
    @schema         = schema
    @data           = data
    @affected_count = nil  # computed on demand
    @sth            = sth
    @binds          = binds
    @type_hash      = type_hash
    @driver         = RDBI::Result::Driver::Array
    @result_driver  = nil

    configure_rewindable
    configure_driver(@driver)
  end

  # The count of results (see RDBI::Result main documentation)
  def result_count
    # Non-rewindable cursors typically will give the number of rows
    # fetched so far...
    @data.size
  end

  # The count of affected rows by a DML statement (see RDBI::Result main documentation)
  def affected_count
    @affected_count ||= @data.affected_count
  end


  #
  # Reload the result. This will:
  #
  # * Execute the statement that yielded this result again, with the original binds
  # * Replace the results and other attributes with the new results.
  #
  def reload
    @data.finish
    res = @sth.execute(*@binds)
    @data           = res.instance_variable_get(:@data)
    @type_hash      = res.instance_variable_get(:@type_hash)
    @schema         = res.instance_variable_get(:@schema)
    @affected_count = nil # recomputed on demand

    configure_rewindable
  end

  #
  # Iterator for Enumerable methods.  Yields a row at a time as translated
  # by the current +driver+.
  #
  def each
    while row = fetch(:next_row)
      yield(row)
    end
  end

  #
  # Reset the index.
  #
  def rewind
    @data.rewind
  end

  #
  # Is this result empty?
  #
  def empty?
    @data.empty?
  end

  #
  # Coerce the underlying result to an array, fetching all values. Same as
  # setting RDBI::Result#rewindable_result.
  #
  def coerce_to_array
    @data.coerce_to_array
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
  # Returns its receiver, permitting method chaining.
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
  # This will force a rewind even if +rewindable_result+ is false.
  #
  def as(driver_klass, *args)

    driver_klass  = RDBI::Util.class_from_class_or_symbol(driver_klass, RDBI::Result::Driver)

    rr = @data.rewindable_result
    @data.rewindable_result = true
    @data.rewind
    @data.rewindable_result = rr
    @driver       = driver_klass
    configure_driver(@driver, *args)
    self
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
  # * :first and :last return nil if there are no results. All others will
  #   return an empty array.
  #
  # == The index
  #
  # I bet you're wondering what that is now, right? Well, the index is
  # essentially a running row count that is altered by certain fetch
  # operations. This makes sequential fetches much simpler.
  #
  # The index is largely implemented by RDBI::Cursor (and Database Driver
  # subclasses)
  #
  # Items that do not use the index do not affect it.
  #
  # Result Drivers will always rewind the index, as this implicates a "point of
  # no return" state change. You may always return to the original driver you
  # were using, but the index position will be lost.
  #
  # The default result driver is RDBI::Result::Driver::Array.
  #
  def fetch(row_count=1, driver_klass=nil, *args)
    if driver_klass
      as(driver_klass, *args)
    end

    # fetch() has two significantly different return signatures:
    #
    # Returning a single row is nil upon EOF (:first, :last, inside #each)
    # Returning a set of rows is [] upon EOF (all others)

    raw, multiple_rows = case row_count
                         when :first, :last, :next_row
                           [@data.__send__(row_count), false]
                         when :all, :rest
                           [@data.__send__(row_count), true]
                         else
                           [@data.fetch(row_count), true]
                         end

    return @result_driver.format_multiple_rows(raw) if multiple_rows

    @result_driver.format_single_row(raw) if raw

    # else nil -- :first, :last or #each at EOF
  end

  #
  # Returns the first result in the set.  Note that this may force an
  # advance of the underlying cursor for non-rewindable ResultSets.
  #
  def first
    fetch(:first)
  end

  #
  # Returns the last result in the set.  Note that this may exhaust the
  # underlying cursor for non-rewindable ResultSets, as the driver advances
  # to the end of the results to fetch the last row.
  #
  def last
    fetch(:last)
  end

  alias read fetch

  #
  # This call finishes the result and the RDBI::Statement handle, scheduling
  # any unpreserved data for garbage collection.
  #
  def finish
    @sth.finish
    @data.finish
    @data   = nil
    @sth    = nil
    @driver = nil
    @binds  = nil
    @schema = nil
  end

  protected

  def configure_driver(driver_klass, *args)
    @result_driver = driver_klass.new(self, *args)
  end

  def configure_rewindable
    @rewindable_result = @sth.rewindable_result
    if self.rewindable_result
      @data.coerce_to_array
    end
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
# at least two methods: +format_single_row+ and +format_multiple_rows+.
#
# +format_single_row+ is called with a single row fetched "raw" from the
# underlying driver, that is, with an array of variously typed elements.  It
# is never called with a nil argument.  +format_multiple_rows+ is called with
# a possibly empty array of raw rows.
#
# Note that +format_multiple_rows+ could be implemented in terms of
# +format_single_row+.  However, for performance reasons it is not.
#
# Base class RDBI::Result::Driver additionally provides the method
# +convert_row+ to employ RDBI's type conversion facility (see RDBI::Type) for
# converting "raw" data elements to convenient ruby types.  For performance
# reasons, RDBI converts on request instead of preemptively, so <b>it is the
# driver implementor's job to do any conversion</b>.
#
class RDBI::Result::Driver

  #
  # Result driver constructor. This is the logic that associates the result
  # driver for decoration over the result; if you wish to override this method,
  # please call +super+ before performing your own operations.
  #
  def initialize(result, *args)
    @result = result
  end

  def format_single_row(raw)
    convert_row(raw)
  end

  def format_multiple_rows(raw_rows)
    raw_rows.collect { |rr| convert_row(rr) }
  end

  protected

  def convert_row(row)
    row.each_with_index do |x, i|
      row[i] = RDBI::Type::Out.convert(x, @result.schema.columns[i], @result.type_hash)
    end

    return row
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

  def format_single_row(raw)
    raw.to_csv
  end

  def format_multiple_rows(raw_rows)
    raw_rows.inject("") do |accum, row| accum << row.to_csv end
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

  def format_single_row(raw)
    struct_klass.new(*super)
  end

  def format_multiple_rows(raw_rows)
    super.collect { |row| struct_klass.new(*row) }
  end

  private
  def struct_klass
    @struct_klass ||= ::Struct.new(*@result.schema.columns.map(&:name))
  end
end

#
# Yields YAML representations of rows, each as an array keyed by the column
# name (as symbol, not string).
#
# For example, a table:
#
#   create table foo (i integer, x varchar);
#   insert into foo (i, x) values (1, "bar");
#   insert into foo (i, x) values (2, "foo");
#   insert into foo (i, x) values (3, "quux");
#
# With a query as such:
#
#   dbh.execute("select * from foo").as(:YAML).fetch(:all)
#
# Will yield:
#
#   --- 
#   - :i: 1
#     :x: bar 
#   - :i: 2
#     :x: foo
#   - :i: 3 
#     :x: quux
#
class RDBI::Result::Driver::YAML < RDBI::Result::Driver
  def initialize(result, *args)
    super
    RDBI::Util.optional_require('yaml')
  end

  def format_single_row(raw)
    ::Hash[column_names.zip(raw)].to_yaml
  end

  def format_multiple_rows(raw_rows)
    raw_rows.collect { |row| ::Hash[column_names.zip(row)] }.to_yaml
  end

  private
  def column_names
    @column_names ||= @result.schema.columns.map(&:name)
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
