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
        yield dbh if block_given?
        return dbh
    end

    def self.connect_cached(klass, *args, &block)
    end

    def self.pool(pool_name=:default)
    end

    def self.ping(klass, *args)
        connect(klass, *args).ping
    end
    
    def self.reconnect_all
    end
end

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

    def initialize(name, connect_args, max=5)
        @handles      = []
        @connect_args = connect_args
        @max          = max
        @last_index   = 0
        @mutex        = Mutex.new
        self.class[name] = self
    end
   
    def ping
        reconnect_if_disconnected
        @mutex.synchronize do 
            @handles.inject(1) { |x,y| x + (y.ping || 1) } / @handles.size
        end
    end

    def reconnect
        @mutex.synchronize do 
            @handles.each(&:reconnect)
        end
    end

    def reconnect_if_disconnected
        @mutex.synchronize do 
            @handles.each do |dbh|
                dbh.reconnect unless dbh.connected?
            end
        end
    end

    def disconnect
        @mutex.synchronize do
            @handles.each(&:disconnect)
        end
    end

    def add_connection
        add(RDBI.connect(*@connect_args))
    end

    def add(dbh)
        dbh = *MethLab.validate_array_params([RDBI::Database], [dbh])
        raise dbh if dbh.kind_of?(Exception)

        @mutex.synchronize do
            if @handles.size >= @max
                raise ArgumentError, "too many handles in this pool (max: #{@max})"
            end

            @handles << dbh
        end

        return self
    end

    # XXX: does not disconnect the dbh - intentional
    def remove(dbh)
        @mutex.synchronize do
            @handles.reject! { |x| x.object_id == dbh.object_id }
        end
    end

    # XXX: does not disconnect the dbh - intentional
    #      will prefer disconnected database handles to remove
    def cull(max=5)
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
end

class RDBI::Database
    # FIXME methlab controls to inline a bunch of crap
   
    attr_reader :connected
    alias_method :connected?, :connected

    def ping
        raise NoMethodError, "ping is not implemented in this driver" 
    end

    def initialize(*args)
        # FIXME symbolify
        @connect_args = args[0]
        @connected = true
    end

    def reconnect
        @connected = true
    end

    def disconnect
        @connected = false
    end
end

require 'driver/mock'

# vim: syntax=ruby ts=4 et sw=4 sts=4
