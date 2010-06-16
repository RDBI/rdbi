class RDBI::Result
  extend MethLab
  include Enumerable

  attr_reader :schema
  attr_reader :sth
  attr_reader :driver
  attr_reader :rows
  attr_reader :type_hash

  def binds
    @binds.dup
  end

  # FIXME async
  inline(:complete, :complete?) { true } 

  inline(:eof, :eof?)           { @index >= @data.size }
  inline(:more, :more?)         { @index  < @data.size }
  inline(:has_data, :has_data?) { @data.size > 0 }

  def initialize(data, schema, sth, binds, type_hash)
    @schema       = schema
    @data         = data
    @rows         = data.size
    @sth          = sth
    @binds        = binds
    @type_hash    = type_hash
    @index        = 0
    @mutex        = Mutex.new
    @driver       = RDBI::Result::Driver::Array
    @fetch_handle = nil 
    as(@driver)
  end

  def each
    yield(fetch[0]) while more?
  end

  def rewind
    @index = 0
  end

  def as(driver_klass, *args)
    # FIXME consistent class logic with RDBI.connect
    driver_klass = begin
                     driver_klass.kind_of?(Class) ? driver_klass : RDBI::Result::Driver.const_get(driver_klass.to_s)
                   rescue
                     raise ArgumentError, "Invalid argument for driver name; must be Class, Symbol, or String"
                   end

    @driver       = driver_klass
    @fetch_handle = driver_klass.new(self, *args) 
  end

  # XXX after some thought, I really don't like this facade approach. Maybe we
  # just want to hand them an inheriting result.
  def fetch(row_count=1, driver_klass=nil, *args)
    if driver_klass
      as(driver_klass, *args)
    end

    @fetch_handle.fetch(row_count)
  end

  alias read fetch

  def raw_fetch(row_count)
    final_res = if row_count == :all
                  Marshal.load(Marshal.dump(@data))
                elsif row_count == :rest
                  res = Marshal.load(Marshal.dump(@data[@index..-1]))
                  @index = @data.size
                  res
                else
                  res = @data[@index..(@index + (row_count - 1))]
                  @index += row_count
                  res
                end
    Marshal.load(Marshal.dump(final_res))
  end

  def finish
    @data   = nil
    @sth    = nil
    @driver = nil
    @binds  = nil
    @schema = nil
    @index  = nil
  end
end

class RDBI::Result::Driver
  def initialize(result, *args)
    @result = result
    @result.rewind
  end

  def fetch(row_count)
    @result.raw_fetch(row_count).map do |row|
      convert_row(row)
    end
  end

  def convert_row(row)
    newrow = []
    row.each_with_index do |x, i|
      newrow.push(RDBI::Type::Out.convert(x, @result.schema.columns[i], @result.type_hash))
    end
    return newrow
  end
end

# standard array driver.
class RDBI::Result::Driver::Array < RDBI::Result::Driver
end

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

class RDBI::Result::Driver::HashPipe < RDBI::Result::Driver
  def initialize(result, *args)
    super

    RDBI::Util.optional_require('hashpipe')
  end

  def fetch(row_count)
    hashes = []
    column_names = @result.schema.columns.map(&:name)

    @result.raw_fetch(row_count).each do |row|
      hash = ::HashPipe.new

      row.each_with_index do |item, i| 
        hash[column_names[i]] = item
      end

      hashes.push(hash)
    end

    return hashes
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
