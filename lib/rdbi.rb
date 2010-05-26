require 'methlab'
require 'thread'

module RDBI
    #
    # FIXME would like to use methlab here, but am not entirely sure how to do this best.
    #
    class << self
        attr_reader :all_connections
        attr_reader :drivers
        attr_reader :last_dbh
    end

    def self.connect(klass, *args)
        klass = case klass
                when Class
                    klass
                when Symbol
                    self::Driver.const_get(klass)
                when String
                    self::Driver.const_get(klass.to_sym)
                else
                    raise ArgumentError, "Invalid argument for driver name; must be Class, Symbol, or String"
                end

        driver = klass.new(*args)
        dbh = @last_dbh = driver.get_handle

        @all_connections ||= []
        @all_connections.push(dbh)

        yield dbh if block_given?
        return dbh
    end

    def self.connect_cached(klass, *args, &block)
        args = args[0]
        pool_name = args[:pool_name] || :default

        dbh = nil

        if RDBI::Pool[pool_name]
            dbh = RDBI::Pool[pool_name].get_dbh
        else
            dbh = RDBI::Pool.new(pool_name, [klass, *args]).get_dbh
        end

        @last_dbh = dbh

        yield dbh if block_given?
        return dbh
    end

    def self.pool(pool_name=:default)
        RDBI::Pool[pool_name]
    end

    def self.ping(klass, *args)
        connect(klass, *args).ping
    end
    
    def self.reconnect_all
        @all_connections.each(&:reconnect)
    end
    
    def self.disconnect_all
        @all_connections.each(&:disconnect)
    end
end

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
    class << self
        def [](name)
            @pools ||= { }
            @pools[name.to_sym]
        end

        def []=(name, value)
            @pools ||= { }
            @pools[name.to_sym] = value
        end
    end

    attr_reader :handles
    attr_reader :last_index
    attr_reader :max
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
 
    #
    # Ping all database connections and average out the amount.
    # 
    # Any disconnected handles will be reconnected before this operation
    # starts.
    def ping
        reconnect_if_disconnected
        @mutex.synchronize do 
            @handles.inject(1) { |x,y| x + (y.ping || 1) } / @handles.size
        end
    end

    #
    # Unconditionally reconnect all database handles.
    def reconnect
        @mutex.synchronize do 
            @handles.each { |dbh| dbh.reconnect } 
        end
    end

    #
    # Only reconnect the database handles that have not been already connected.
    def reconnect_if_disconnected
        @mutex.synchronize do 
            @handles.each do |dbh|
                dbh.reconnect unless dbh.connected?
            end
        end
    end

    # 
    # Disconnect all database handles.
    def disconnect
        @mutex.synchronize do
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
        @mutex.synchronize do
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
        @mutex.synchronize do
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
        @mutex.synchronize do
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

        @mutex.synchronize do
            if @handles.size >= @max
                raise ArgumentError, "too many handles in this pool (max: #{@max})"
            end

            @handles << dbh
        end

        return self
    end
end

class RDBI::Database
    extend MethLab
   
    inline(:connected, :connected?) { @connected }

    inline(:reconnect)  { @connected = true  }
    inline(:disconnect) { @connected = false }

    inline(:ping) { raise NoMethodError, "this method is not implemented in this driver" }

    def initialize(*args)
        # FIXME symbolify
        @connect_args = args[0]
        @connected = true
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
