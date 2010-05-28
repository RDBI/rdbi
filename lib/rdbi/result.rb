class RDBI::Result
  include Enumerable

  inline(
    :complete?,
    :has_data?,
    :eof?,
    :rewind,
    :as,
    :fetch,
    :raw_fetch,
    :finish,
    :schema,
    :each
  ) { |*args| raise NoMethodError, "not done yet" }

  attr_reader :sth
  attr_reader :driver
  attr_reader :rows

  def binds
    @binds.dup
  end

  def initialize(data, schema, sth, binds)
    @schema = schema
    @data   = data
    @rows   = data.size
    @sth    = sth
    @binds  = binds
    @index  = 0
    @driver = RDBI::Result::Driver::Array
  end
end

class RDBI::Result::Driver
  inline(:fetch) { |row_count| raise NoMethodError, "Your driver needs to implement this method to be useful" }

  def initialize(result, *args)
    result.rewind
  end
end

# standard array driver.
class RDBI::Result::Driver::Array < RDBI::Result::Driver
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
