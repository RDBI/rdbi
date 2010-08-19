#
# RDBI::Cursor is a method of abstractly encapsulating result handles that we
# get back from databases. It has a consistent interface and therefore can be
# used by RDBI::Result and its drivers.
#
# Drivers should make a whole-hearted attempt to do iterative fetching instead
# of array fetching.. this will perform much better for larger results.
#
# RDBI::Cursor is largely an abstract class and will error if methods are not
# implemented in an inheriting class. Please read the individual method
# documentation for what each call should yield.
#
class RDBI::Cursor
  #
  # Exception which indicates that the inheriting class has not implemented
  # these interface calls.
  #
  class NotImplementedError < Exception; end

  extend MethLab
  include Enumerable

  # underlying handle.
  
  attr_reader :handle

  # Default constructor. Feel free to override this.
  #
  def initialize(handle)
    @handle = handle
  end

 
  # Returns the next row in the result.
  def next_row; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Returns the count of rows that exist in this result.
  def result_count; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Returns the number of affected rows (DML) in this result.
  def affected_count; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Returns the first tuple in the result.
  def first; raise NotImplementedError, 'Subclasses must implement this method'; end
 
  # Returns the last tuple in the result.
  def last; raise NotImplementedError, 'Subclasses must implement this method'; end
 
  # Returns the items that have not been fetched yet in this result. Equivalent
  # to all() if the fetched count is zero.
  def rest; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Returns all the tuples.
  def all; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Fetches +count+ tuples from the result and returns them.
  def fetch(count=1); raise NotImplementedError, 'Subclasses must implement this method'; end

  # Fetches the tuple at position +index+.
  def [](index); raise NotImplementedError, 'Subclasses must implement this method'; end

  # Are we on the last row?
  def last_row?; raise NotImplementedError, 'Subclasses must implement this method'; end

  # Is this result empty?
  def empty?; raise NotImplementedError, 'Subclasses must implement this method'; end

  # rewind the result to start again from the top.
  def rewind; raise NotImplementedError, 'Subclasses must implement this method'; end

  # See result_count().
  def size
    result_count
  end

  # Finish this cursor and schedule it for termination. 
  def finish
  end

  # Enumerable helper. Iterate over each item and yield it to a block.
  def each
    yield next_row until last_row? 
  end
end
