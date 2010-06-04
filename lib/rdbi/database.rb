#
# RDBI::Database is the base class for database handles. This is the primary
# method in which most users will access their database system.
#
# To execute statements, look at +prepare+ and +execute+.
#
# To retrieve schema information, look at +schema+ and +table_schema+.
#
# To deal with transactions, +transaction+, +commit+, and +rollback+.
class RDBI::Database
  extend MethLab

  # the driver class that is responsible for creating this database handle.
  attr_accessor :driver
  
  # the name of the database we're connected to, if any.
  attr_accessor :database_name

  # the last statement handle allocated. affected by +prepare+ and +execute+.
  attr_reader :last_statement

  # are we currently in a transaction?
  inline(:in_transaction, :in_transaction?) { @in_transaction }

  # the last query sent, as a string.
  attr_reader :last_query

  # the mutex for this database handle.
  attr_reader :mutex

  inline(:connected, :connected?) { @connected }

  inline(:reconnect)  { @connected = true  }
  inline(:disconnect) { @connected = false }

  inline(:bind_style) { raise NoMethodError, "unimplemented in this version" }
  inline(
    :ping, 
    :table_schema, 
    :schema
  ) { |*args| raise NoMethodError, "this method is not implemented in this driver" }

  inline(:commit, :rollback) { @in_transaction = false }

  #
  # Create a new database handle. This is typically done by a driver and
  # likely shouldn't be done directly.
  #
  # args is the connection arguments the user initially supplied to
  # RDBI.connect.
  def initialize(*args)
    # FIXME symbolify
    @connect_args = args[0]
    @connected    = true
    @mutex        = Mutex.new
  end

  #
  # Open a new transaction for processing. Accepts a block which will execute
  # the portions during the transaction.
  #
  # Example:
  #
  #   dbh.transaction do |dbh|
  #       dbh.execute("some query")
  #       dbh.execute("some other query")
  #       raise "oh crap!" # would rollback
  #       dbh.commit # commits
  #       dbh.rollback # rolls back
  #   end
  #
  #   # at this point, if no raise or commit/rollback was triggered, it would
  #   # commit.
  #
  # Any exception that isn't caught within this block will trigger a
  # rollback. Additionally, you may use +commit+ and +rollback+ directly
  # within the block to terminate the transaction early -- at which point
  # *the transaction is over with and you may be in autocommit*. The
  # RDBI::Database accessor +in_transaction+ exists to tell you if RDBI
  # thinks its in a transaction or not. 
  #
  # If you do not +commit+ or +rollback+ within the block and no exception is
  # raised, RDBI presumes you wish this transaction to succeed and commits
  # for you.
  #
  def transaction(&block)
    @in_transaction = true
    begin
      yield self
      self.commit if @in_transaction
    rescue => e
      self.rollback 
      raise e
    ensure
      @in_transaction = false
    end
  end

  #
  # Prepares a statement for execution. Takes a query as its only argument,
  # returns a RDBI::Statement.
  #
  def prepare(query)
    sth = nil
    mutex.synchronize do
      @last_query = query
      sth = new_statement(query)
      yield sth if block_given?
    end

    return @last_statement = sth
  end
 
  #
  # Prepares and executes a statement. Takes a string query and an optional
  # number of variable type binds.
  #
  def execute(query, *binds)
    res = nil

    mutex.synchronize do
      @last_query = query
      @last_statement = sth = new_statement(query)
      res = sth.execute(*binds)
      sth.finish
      yield res if block_given?
    end

    return res
  end

  #
  # Process the query as your driver would normally, and return the result.
  # Depending on the driver implementation and potentially connection
  # settings, this may include interpolated data or client binding
  # placeholders.
  #
  def preprocess_query(query, *binds)
    mutex.synchronize do
      @last_query = query
    end

    ep = Epoxy.new(query)
    ep.quote { |x| %Q{'#{binds[x].to_s.gsub(/'/, "''")}'} }
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
