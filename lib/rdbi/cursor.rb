class RDBI::Cursor
  class NotImplementedError < Exception; end

  extend MethLab
  include Enumerable

  attr_reader :handle

  def initialize(handle)
    @handle = handle
  end

  inline(
    :next_row,
    :result_count,
    :affected_count,
    :first,
    :last,
    :rest,
    :all,
    :fetch,
    :[],
    :last_row?,
    :empty?,
    :rewind
  ) do
    raise NotImplementedError, 'Subclasses must implement this method'
  end

  def size
    result_count
  end

  def finish
  end

  def each
    yield next_row until last_row? 
  end
end
