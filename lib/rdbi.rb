require 'epoxy'
require 'methlab'
require 'thread'

module RDBI
    #
    # FIXME would like to use methlab here, but am not entirely sure how to do this best.
    #
    class << self
        #
        # Every database handle allocated throughout the lifetime of the
        # program. This functionality is subject to change and may be pruned
        # during disconnection.
        attr_reader :all_connections
        #--
        #attr_reader :drivers
        #++
        #
        # The last database handle allocated. This may come from pooled connections or regular ones.
        attr_reader :last_dbh
    end

    #
    # connect() takes a class name, which may be represented as:
    #
    # * The full class name, such as RDBI::Driver::Mock
    # * A symbol representing the significant portion, such as :Mock, which corresponds to RDBI::Driver::Mock
    # * A string representing the same data as the symbol.
    #
    # Additionally, arguments that are passed on to the driver for consumption
    # may be passed. Please refer to the driver documentation for more
    # information.
    #
    # connect() returns an instance of RDBI::Database. In the instance a block
    # is provided, it will be called upon connection success, with the
    # RDBI::Database object provided in as the first argument.
    def self.connect(klass, *args)

        klass = begin
                    klass.kind_of?(Class) ? klass : self::Driver.const_get(klass.to_s)
                rescue
                    raise ArgumentError, "Invalid argument for driver name; must be Class, Symbol, or String"
                end

        driver = klass.new(*args)
        dbh = @last_dbh = driver.new_handle

        @all_connections ||= []
        @all_connections.push(dbh)

        yield dbh if block_given?
        return dbh
    end

    #
    # connect_cached() works similarly to connect, but yields a database handle
    # copied from a RDBI::Pool. The 'default' pool is the ... default, but this
    # may be manipulated by providing :pool_name to the connection arguments.
    #
    # If a pool does not exist already, it will be created and a database
    # handle instanced from your connection arguments.
    #
    # If a pool *already* exists, your connection arguments will be ignored and
    # it will instance from the Pool's connection arguments.
    def self.connect_cached(klass, *args)
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

    #
    # Retrieves a RDBI::Pool. See RDBI::Pool.[].
    def self.pool(pool_name=:default)
        RDBI::Pool[pool_name]
    end

    #
    # Connects to and pings the database. Arguments are the same as for RDBI.connect.
    def self.ping(klass, *args)
        connect(klass, *args).ping
    end
   
    #
    # Reconnects all known connections. See RDBI.all_connections.
    def self.reconnect_all
        @all_connections.each(&:reconnect)
    end
   
    #
    # Disconnects all known connections. See RDBI.all_connections.
    def self.disconnect_all
        @all_connections.each(&:disconnect)
    end
end

class RDBI::Driver
    attr_reader :connect_args
    attr_reader :dbh_class

    def initialize(dbh_class, *args)
        @dbh_class = dbh_class
        @connect_args = args
    end

    def new_handle 
        dbh = @dbh_class.new(*@connect_args)
        dbh.driver = self.class
        return dbh
    end
end

require 'rdbi/pool'
require 'rdbi/driver'
require 'rdbi/database'
require 'rdbi/statement'
require 'rdbi/schema'

# vim: syntax=ruby ts=4 et sw=4 sts=4
