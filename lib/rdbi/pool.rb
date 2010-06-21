#
# RDBI::Pool - Connection Pooling.
#
# Pools are named resources that consist of N concurrent connections which all
# have the same properties. Many group actions can be performed on them, such
# as disconnecting the entire lot.
#
# RDBI::Pool itself has a global accessor, by way of RDBI::Pool.[], that can
# access these pools by name. Alternatively, you may access them through the
# RDBI.pool interface.
#
# Pools are thread-safe and are capable of being resized without disconnecting
# the culled database handles.
#
class RDBI::Pool

  @mutex = Mutex.new

  class << self
    include Enumerable

    # Iterate each pool and get the name of the pool (as a symbol) and the
    # value as a Pool object.
    def each
      @pools.each do |key, value|
        yield(key, value)
      end
    end

    # obtain the names of each pool.
    def keys
      @pools.keys
    end

    # obtain the pool objects of each pool.
    def values
      @pools.values
    end

    #
    # Retrieves a pool object for the name, or nothing if it does not exist.
    def [](name)
      mutex.synchronize do
        @pools ||= { }
        @pools[name.to_sym]
      end
    end

    #
    # Sets the pool for the name. This is not recommended for end-user code.
    def []=(name, value)
      mutex.synchronize do
        @pools ||= { }
        @pools[name.to_sym] = value
      end
    end

    def mutex
      @mutex
    end
  end

  include Enumerable

  # a list of the pool handles for this object. Do not manipulate this directly.
  attr_reader :handles
  # the last index corresponding to the latest allocation request.
  attr_reader :last_index
  # the maximum number of items this pool can hold. should only be altered by resize.
  attr_reader :max
  # the Mutex for this pool.
  attr_reader :mutex

  #
  # Creates a new pool.
  #
  # * name: the name of this pool, which will be used to find it in the global accessor.
  # * connect_args: an array of arguments that would be passed to RDBI.connect, including the driver name.
  # * max: the maximum number of connections to deal with.
  #
  # Usage:
  #
  # Pool.new(:fart, [:SQLite3, :database => "/tmp/foo.db"])
  def initialize(name, connect_args, max=5)
    @handles      = []
    @connect_args = connect_args
    @max          = max
    @last_index   = 0
    @mutex        = Mutex.new
    self.class[name] = self
  end

  # Obtain each database handle in the pool.
  def each
    @handles.each { |dbh| yield dbh }
  end

  #
  # Ping all database connections and average out the amount.
  # 
  # Any disconnected handles will be reconnected before this operation
  # starts.
  def ping
    reconnect_if_disconnected
    mutex.synchronize do 
      @handles.inject(1) { |x,y| x + (y.ping || 1) } / @handles.size
    end
  end

  #
  # Unconditionally reconnect all database handles.
  def reconnect
    mutex.synchronize do 
      @handles.each { |dbh| dbh.reconnect } 
    end
  end

  #
  # Only reconnect the database handles that have not been already connected.
  def reconnect_if_disconnected
    mutex.synchronize do 
      @handles.each do |dbh|
        dbh.reconnect unless dbh.connected?
      end
    end
  end

  # 
  # Disconnect all database handles.
  def disconnect
    mutex.synchronize do
      @handles.each(&:disconnect)
    end
  end

  #
  # Add a connection, connecting automatically with the connect arguments
  # supplied to the constructor.
  def add_connection
    add(RDBI.connect(*@connect_args))
  end

  #
  # Remove a specific connection. If this connection does not exist in the
  # pool already, nothing will occur.
  #
  # This database object is *not* disconnected -- it is your responsibility
  # to do so.
  def remove(dbh)
    mutex.synchronize do
      @handles.reject! { |x| x.object_id == dbh.object_id }
    end
  end

  #
  # Resize the pool. If the new pool size is smaller, connections will be
  # forcibly removed, preferring disconnected handles over connected ones.
  #
  # No database connections are disconnected.
  #
  # Returns the handles that were removed, if any.
  #
  def resize(max=5)
    mutex.synchronize do
      in_pool = @handles.select(&:connected?)

      unless (in_pool.size >= max)
        disconnected = @handles.select { |x| !x.connected? }
        if disconnected.size > 0
          in_pool += disconnected[0..(max - in_pool.size - 1)]
        end
      else
        in_pool = in_pool[0..(max-1)]
      end

      rejected = @handles - in_pool

      @max = max
      @handles = in_pool
      rejected
    end
  end

  #
  # Obtain a database handle from the pool. Ordering is round robin.
  #
  # A new connection may be created if it fills in the pool where a
  # previously empty object existed. Additionally, if the current database
  # handle is disconnected, it will be reconnected.
  # 
  def get_dbh
    mutex.synchronize do
      if @last_index >= @max
        @last_index = 0
      end

      # XXX this is longhand for "make sure it's connected before we hand it
      #     off"
      if @handles[@last_index] and !@handles[@last_index].connected?
        @handles[@last_index].reconnect
      elsif !@handles[@last_index]
        @handles[@last_index] = RDBI.connect(*@connect_args)
      end

      dbh = @handles[@last_index]
      @last_index += 1
      dbh
    end
  end

  protected 

  #
  # Add any ol' database handle. This is not for global consumption.
  #
  def add(dbh)
    dbh = *MethLab.validate_array_params([RDBI::Database], [dbh])
    raise dbh if dbh.kind_of?(Exception)

    dbh = dbh[0] if dbh.kind_of?(Array)

    mutex.synchronize do
      if @handles.size >= @max
        raise ArgumentError, "too many handles in this pool (max: #{@max})"
      end

      @handles << dbh
    end

    return self
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
