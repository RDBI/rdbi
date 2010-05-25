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
        dbh = driver.get_handle
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

class RDBI::Handle
    def ping
        nil
    end
end

require 'driver/mock'
