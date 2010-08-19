class RDBI::Cursor
  class NotImplementedError < Exception; end

  extend MethLab
  include Enumerable

  attr_reader :handle
  attr_threaded_accessor :mutex

  def initialize(handle)
    @handle = handle
    @mutex  = Mutex.new
  end

  inline(
    :next_row,
    :result_count,
    :affected_count,
    :fetch,
    :first,
    :last,
    :rest,
    :all,
    :[],
    :last_row?,
    :rewind
  ) do
    raise NotImplementedError, 'Subclasses must implement this method'
  end

  def finish
  end

  def each
    yield next_row until last_row? 
  end
end
