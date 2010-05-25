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

class Pool
    class << self
        attr_reader :pools

        @pools = { }
    end

    def self.[](name)
        pools[name.to_sym]
    end

    def self.[]=(name, value)
        pools[name.to_sym] = value
    end

    attr_reader :handles
    attr_reader :last_index

    def initialize(name, connect_args, max=5)
        @handles      = []
        @connect_args = connect_args
        @max          = max
        @last_index   = 0
    end
   
    def ping
        reconnect_if_disconnected
        @handles.map { |x| x.ping || 0 } / @handles.size
    end

    def reconnect
        @handles.each(&:reconnect)
    end

    def reconnect_if_disconnected
        @handles.each do |dbh|
            dbh.reconnect unless dbh.connected?
        end
    end

    def disconnect
        @handles.each(&:disconnect)
    end

    def add_connection
        add(RDBI.connect(*@connect_args))
    end

    def add(dbh)
        dbh = *MethLab.validate_array_params([RDBI::Database], dbh)
        raise dbh if dbh.kind_of?(Exception)

        if ((@handles.size + 1) == @max)
            raise ArgumentError, "too many handles in this pool (max: #{@max})"
        end

        @handles << dbh
    end

    # XXX: does not disconnect the dbh - intentional
    def remove(dbh)
        @handles.reject! { |x| x.object_id == dbh.object_id }
    end

    # XXX: does not disconnect the dbh - intentional
    #      will prefer disconnected database handles to remove
    def cull(max=5)
        in_pool = @handles.select(&:connected?)

        unless ((in_pool.size + 1) >= max)
            disconnected = @handles.select { |x| !x.connected? }
            if disconnected.size > 0
                in_pool += disconnected[0..(max - connected.size - 1)]
            end
        else
            in_pool = in_pool[0..(max-1)]
        end

        rejected = @handles - connected

        return rejected
    end

    def get_dbh
        if @last_index == @max
            @last_index = 0
        end

        if @handles[@last_index] and !@handles[@last_index].connected?
            @handles[@last_index].reconnect
        elsif !@handles[@last_index]
            @handles[@last_index] = RDBI.connect(*@connect_args)
        end

        dbh = @handles[@last_index]
        @last_index += 1

        return dbh
    end
end

class RDBI::Database
    # FIXME methlab controls to inline a bunch of crap
   
    attr_reader :connected
    alias_method :connected, :connected?

    def ping
        nil
    end

    def initialize
        @connected = true
    end

    def disconnected
        @connected = false
    end
end

require 'driver/mock'

# vim: syntax=ruby ts=4 et sw=4 sts=4
