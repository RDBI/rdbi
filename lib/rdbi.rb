require 'epoxy'

module RDBI

  VERSION = '1.1.0'

  class << self
    #
    # The last database handle allocated. This may come from pooled connections or regular ones.
    #
    attr_accessor :last_dbh
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
  # RDBI::Database object provided in as the first argument, and the
  # connection will be automatically disconnected at the end of the block.
  def self.connect(klass, *args)

    klass = case klass
            when ::Class
              klass
            when ::String, ::Symbol
              Util.resolve_driver(klass)
            else
              raise ArgumentError.new("Invalid driver specification")
            end

    driver = klass.new(*args)
    dbh = self.last_dbh = driver.new_handle

    return dbh unless block_given?

    begin
        yield dbh
    ensure
        dbh.disconnect rescue nil
    end
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
  #
  # If a block is provided, the connection is *not* disconnected at the end
  # of the block.
  def self.connect_cached(klass, *args)
    args = args[0]
    pool_name = args[:pool_name] || :default

    dbh = nil

    if pool = RDBI::Pool[pool_name]
      dbh = pool.get_dbh
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

  # Require and swallow errors.  Returns true if module loaded (for the first
  # time), false if already loaded or unable to load
  def self.naive_require(lib)
    require lib
  rescue LoadError
    nil
  end

  # Given a short driver name (e.g., :FauxSQL), return the corresponding
  # class, attempting to load the driver library if needed.
  def self.resolve_driver(driver)
    loop do
      return ::RDBI::Driver.const_get(driver.to_sym) if ::RDBI::Driver.const_defined?(driver.to_sym)
      # const_defined? will throw a NameError if driver is not a valid
      # constant name
      redo if naive_require("rdbi-driver-#{driver.to_s.downcase}")
      redo if naive_require("rdbi/driver/#{driver.to_s.downcase}")
      break
    end
    raise ArgumentError.new("Unable to qualify driver #{driver}")
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

  def self.index_binds(args, index_map)
    # FIXME exception if mixed hash/indexed binds
    
    if args.empty? or !args.find { |x| x.kind_of?(Hash) }
      return args
    end

    if args.kind_of?(Hash)
      binds = []
      hash = args
    else
      hashes, binds = args.partition { |x| x.kind_of?(Hash) }
      hash = hashes.inject({ }, :merge)
    end

    hash.each do |key, value| 
      # XXX yes, we want to *assign* here.
      if index = index_map.index(key)
        binds.insert(index, value)
      end
    end
    return binds
  end

  def self.upon_finalize!(what, o, meth, *args)
    ObjectSpace.define_finalizer(what, make_fini_proc(o, meth, *args))
  end

  def self.make_fini_proc(obj, meth, *args)
    proc { |object_id| obj.__send__(meth.to_sym, *args) rescue nil }
  end

end # -- module RDBI::Util

require 'rdbi/types'
require 'rdbi/pool'
require 'rdbi/driver'
require 'rdbi/database'
require 'rdbi/statement'
require 'rdbi/schema'
require 'rdbi/result'
require 'rdbi/cursor'

# vim: syntax=ruby ts=2 et sw=2 sts=2
