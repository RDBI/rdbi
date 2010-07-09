class RDBI::Result
  extend MethLab
  include Enumerable

  attr_reader :schema
  attr_reader :sth
  attr_reader :driver
  attr_reader :result_count
  attr_reader :affected_count
  attr_reader :type_hash
  attr_reader :binds

  # FIXME async
  inline(:complete, :complete?) { true }

  inline(:eof, :eof?)           { @index >= @data.size }
  inline(:more, :more?)         { @index  < @data.size }
  inline(:has_data, :has_data?) { @data.size > 0 }

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

  def reload
    res = @sth.execute(*@binds)
    @data           = res.instance_eval { @data }
    @type_hash      = res.instance_eval { @type_hash }
    @schema         = res.instance_eval { @schema }
    @result_count   = res.instance_eval { @result_count }
    @affected_count = res.instance_eval { @affected_count }
    @index          = 0
  end

  def each
    yield(fetch[0]) while more?
  end

  def rewind
    @index = 0
  end

  def as(driver_klass, *args)

    driver_klass  = RDBI::Util.class_from_class_or_symbol(driver_klass, RDBI::Result::Driver)

    @driver       = driver_klass
    @fetch_handle = driver_klass.new(self, *args)
  end

  def fetch(row_count=1, driver_klass=nil, *args)
    if driver_klass
      as(driver_klass, *args)
    end

    @fetch_handle.fetch(row_count)
  end

  alias read fetch

  # stub docs:
  #
  # * symbols do not affect the index
  # * :first and :last yield a single array.
  # * numbers do
  # * Marshal.dump(Marshal.load) is the best way to deep clone that I know of.
  #   I know it's slow. If you have code to speed it up, please contribute.
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

class RDBI::Result::Driver
  def initialize(result, *args)
    @result = result
    @result.rewind
  end

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

  def convert_row(row)
    newrow = []
    row.each_with_index do |x, i|
      newrow.push(convert_item(x, @result.schema.columns[i]))
    end
    return newrow
  end

  def convert_item(item, column)
    RDBI::Type::Out.convert(item, column, @result.type_hash)
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
