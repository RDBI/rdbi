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
  attr_threaded_accessor :last_statement

  # the last query sent, as a string.
  attr_threaded_accessor :last_query

  # all the open statement handles.
  attr_threaded_accessor :open_statements

  # are we currently in a transaction?
  inline(:in_transaction, :in_transaction?) { @in_transaction > 0 }

  # the mutex for this database handle.
  attr_reader :mutex

  # are we connected to the database?
  inline(:connected, :connected?) { @connected }

  # ping the database. yield an integer result on success.
  inline(:ping) { raise NoMethodError, "this method is not implemented in this driver" }

  # query the schema for a specific table. Returns a RDBI::Schema object.
  inline(:table_schema) { |*args| raise NoMethodError, "this method is not implemented in this driver" }

  # query the schema for the entire database. Returns an array of RDBI::Schema objects.
  inline(:schema) { |*args| raise NoMethodError, "this method is not implemented in this driver" }

  # ends the outstanding transaction and rolls the affected rows back.
  inline(:rollback) { @in_transaction -= 1 unless @in_transaction == 0 }
  
  # ends the outstanding transaction and commits the result.
  inline(:commit)   { @in_transaction -= 1 unless @in_transaction == 0 }

  #
  # Create a new database handle. This is typically done by a driver and
  # likely shouldn't be done directly.
  #
  # args is the connection arguments the user initially supplied to
  # RDBI.connect.
  def initialize(*args)
    # FIXME symbolify
    @connect_args   = args[0]
    @connected      = true
    @mutex          = Mutex.new
    @in_transaction = 0
    self.open_statements = []
  end

  # reconnect to the database. Any outstanding connection will be terminated.
  def reconnect
    disconnect rescue nil
    @connected = true
  end

  #
  # disconnects from the database: will close (and complain, loudly) any
  # statement handles left open.
  #
  def disconnect
    unless self.open_statements.empty?
      warn "[RDBI] Open statements during disconnection -- automatically finishing. You should fix this."
      self.open_statements.each(&:finish)
    end
    self.open_statements = []
    @connected = false
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
    @in_transaction += 1
    begin
      yield self
      self.commit if @in_transaction > 0
    rescue => e
      self.rollback
      raise e
    ensure
      @in_transaction -= 1 unless @in_transaction == 0
    end
  end

  #
  # Prepares a statement for execution. Takes a query as its only argument,
  # returns a RDBI::Statement.
  #
  # ex:
  #   sth = dbh.prepare("select * from foo where item = ?")
  #   res = sth.execute("an item")
  #   ary = res.to_a
  #   sth.finish
  #
  # You can also use a block form which will auto-finish:
  #   dbh.prepare("select * from foo where item = ?") do |sth|
  #     sth.execute("an item")
  #   end
  #
  def prepare(query)
    sth = nil
    mutex.synchronize do
      self.last_query = query
      sth = new_statement(query)
      yield sth if block_given?
      sth.finish if block_given?
    end

    return self.last_statement = sth
  end

  #
  # Prepares and executes a statement. Takes a string query and an optional
  # number of variable type binds.
  #
  # ex:
  #   res = dbh.execute("select * from foo where item = ?", "an item")
  #   ary = res.to_a
  #
  # You can also use a block form which will finish the statement and yield the
  # result handle:
  #   dbh.execute("select * from foo where item = ?", "an item") do |res|
  #     res.as(:Struct).fetch(:all).each do |struct|
  #       p struct.item
  #     end
  #   end
  def execute(query, *binds)
    res = nil

    mutex.synchronize do
      self.last_query = query
      self.last_statement = sth = new_statement(query)
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
      self.last_query = query
    end

    ep = Epoxy.new(query)
    ep.quote { |x| %Q{'#{binds[x].to_s.gsub(/'/, "''")}'} }
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
