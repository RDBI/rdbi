require 'epoxy'
require 'methlab'
require 'fastthread'

module RDBI
  class << self
    extend MethLab

    # Every database handle allocated throughout the lifetime of the
    # program. This functionality is subject to change and may be pruned
    # during disconnection.
    attr_reader :all_connections

    #
    # The last database handle allocated. This may come from pooled connections or regular ones.
    #
    attr_threaded_accessor :last_dbh
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

    klass = RDBI::Util.class_from_class_or_symbol(klass, self::Driver)

    driver = klass.new(*args)
    dbh = self.last_dbh = driver.new_handle

    @all_connections ||= []
    @all_connections.push(dbh)

    yield dbh if block_given?
    return dbh
  end

  #
  # connect_cached() works similarly to connect, but yields a database handle
  # copied from an RDBI::Pool. The 'default' pool is the ... default, but this
  # may be manipulated by setting :pool_name in the connection arguments.
  #
  # If a pool does not exist already, it will be created and a database
  # handle instantiated using your connection arguments.
  #
  # If a pool *already* exists, your connection arguments will be ignored and
  # it will instantiate from the Pool's connection arguments.
  def self.connect_cached(klass, *args)
    args = args[0]
    pool_name = args[:pool_name] || :default

    dbh = nil

    if RDBI::Pool[pool_name]
      dbh = RDBI::Pool[pool_name].get_dbh
    else
      dbh = RDBI::Pool.new(pool_name, [klass, args]).get_dbh
    end

    self.last_dbh = dbh

    yield dbh if block_given?
    return dbh
  end

  #
  # Retrieves an RDBI::Pool. See RDBI::Pool.[].
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

  #
  # Base Error class for RDBI. Rescue this to catch all RDBI-specific errors.
  #
  class Error < StandardError
  end

  #
  # This error will be thrown if an operation is attempted while the database
  # is disconnected.
  #
  class DisconnectedError < Error
  end

  #
  # This error will be thrown if an operation is attempted that violated
  # transaction semantics.
  #
  class TransactionError < Error
  end
end

#
# RDBI::Util is a set of utility methods used internally. It is not geared for
# public consumption.
#
module RDBI::Util
  #
  # Requires with a LoadError check and emits a friendly "please install me"
  # message.
  #
  def self.optional_require(lib)
    require lib
  rescue LoadError => e
    raise LoadError, "The '#{lib}' gem is required to use this driver. Please install it."
  end

  #
  # This is the loading logic we use to import drivers of various natures.
  #
  def self.class_from_class_or_symbol(klass, namespace)
    klass.kind_of?(Class) ? klass : namespace.const_get(klass.to_s)
  rescue
    raise ArgumentError, "Invalid argument for driver name; must be Class, or a Symbol or String identifying the Class, and the driver Class must have been loaded"
  end

  #
  # Rekey a string-keyed hash with equivalent symbols.
  #
  def self.key_hash_as_symbols(hash)
    return nil unless hash

    Hash[hash.map { |k,v| [k.to_sym, v] }]
  end

  #
  # Copy an object and all of its descendants to form a new tree
  #
  def self.deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  end

  #
  # Takes an array and appropriate boxes/deboxes it based on what was
  # requested.
  #
  #--
  # FIXME this is a really poorly performing way of doing this.
  #++
  def self.format_results(row_count, ary)
    case row_count
    when :first, :last
      ary = ary[0]
      return nil if ary and ary.empty?
      return ary
    else
      return ary
    end
  end

  def self.index_binds(args, index_map)
    # FIXME exception if mixed hash/indexed binds
    if args[0].kind_of?(Hash)
      binds = []
      args[0].keys.each do |key| 
        if index = index_map.index(key)
          binds.insert(index, args[0][key])
        end
      end
      return binds
    else
      return args
    end
  end
end

require 'rdbi/types'
require 'rdbi/pool'
require 'rdbi/driver'
require 'rdbi/database'
require 'rdbi/statement'
require 'rdbi/schema'
require 'rdbi/result'
require 'rdbi/cursor'

# vim: syntax=ruby ts=2 et sw=2 sts=2
