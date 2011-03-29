#
# RDBI::Database is the base class for database handles.  Most users will
# access their database system through this class.
#
# To execute statements, look at +prepare+ and +execute+.
#
# To retrieve schema information, look at +schema+ and +table_schema+.
#
# To deal with transactions, refer to +transaction+, +commit+, and +rollback+.
class RDBI::Database
  # the driver class that is responsible for creating this database handle.
  attr_accessor :driver

  # the name of the database we're connected to, if any.
  attr_accessor :database_name

  # see RDBI::Statement#rewindable_result
  attr_accessor :rewindable_result

  # the arguments used to create the connection.
  attr_reader :connect_args

  # the last statement handle allocated. affected by +prepare+ and +execute+.
  attr_accessor :last_statement
 
  # the last query sent, as a string.
  attr_accessor :last_query

  # all the open statement handles.
  attr_accessor :open_statements

  # are we currently in a transaction?
  def in_transaction
    @in_transaction > 0
  end

  alias in_transaction? in_transaction

  # are we connected to the database?

  attr_reader :connected
  alias connected? connected

  # ping the database. yield an integer result on success.
  def ping
    raise NoMethodError, "this method is not implemented in this driver"
  end

  # query the schema for a specific table. Returns an RDBI::Schema object.
  def table_schema(table_name)
    raise NoMethodError, "this method is not implemented in this driver"
  end

  # query the schema for the entire database. Returns an array of RDBI::Schema objects.
  def schema
    raise NoMethodError, "this method is not implemented in this driver"
  end

  # ends the outstanding transaction and rolls the affected rows back.
  def rollback
    @in_transaction -= 1 unless @in_transaction == 0
  end

  # ends the outstanding transaction and commits the result.
  def commit
    @in_transaction -= 1 unless @in_transaction == 0 
  end

  #
  # Create a new database handle. This is typically done by a driver and
  # likely shouldn't be done directly.
  #
  # args is the connection arguments the user initially supplied to
  # RDBI.connect.
  def initialize(*args)
    @connect_args         = RDBI::Util.key_hash_as_symbols(args[0])
    @connected            = true
    @in_transaction       = 0
    @rewindable_result    = false
    @preprocess_quoter    = nil
    self.open_statements  = { }
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
    @connected = false
    self.open_statements.values.each { |x| x.finish if x }
    self.open_statements = { }
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
  # returns an RDBI::Statement.
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

    self.last_query = query
    self.last_statement = sth = new_statement(query)

    return sth unless block_given?

    begin
      yield sth
    ensure
      sth.finish rescue nil
    end
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
  #
  # Which will be considerably more performant under some database drivers.
  #
  def execute(query, *binds)
    res = nil

    self.last_query = query
    self.last_statement = sth = new_statement(query)
    res = sth.execute(*binds)

    return res unless block_given?

    begin
      yield res
    ensure
      res.finish rescue nil
    end
  end

  def execute_modification(query, *binds)
    self.last_statement = sth = new_statement(query)
    rows = sth.execute_modification(*binds)
    sth.finish
    return rows
  end

  #
  # Process the query as your driver would normally, and return the result.
  # Depending on the driver implementation and potentially connection
  # settings, this may include interpolated data or client binding
  # placeholders.
  #
  # <b>Driver Authors</b>: if the instance variable @preprocess_quoter is set
  # to a proc that accepts an index/key, a map of named binds and an array of
  # indexed binds, it will be called instead of the default quoter and there is
  # no need to override this method. For example:
  #
  #   def initialize(...)
  #     @preprocess_quoter = proc do |x, named, indexed|
  #       @some_handle.quote((named[x] || indexed[x]).to_s)
  #     end
  #   end
  #
  # This will use RDBI's code to manage the binds before quoting, but use your
  # quoter during bind processing.
  #
  def preprocess_query(query, *binds)
    self.last_query = query

    ep = Epoxy.new(query)

    hashes = binds.select { |x| x.kind_of?(Hash) }
    binds.collect! { |x| x.kind_of?(Hash) ? nil : x }
    total_hash = hashes.inject({}) { |x, y| x.merge(y) }

    if @preprocess_quoter.respond_to?(:call)
      ep.quote(total_hash) { |x| @preprocess_quoter.call(x, total_hash, binds) }
    else
      ep.quote(total_hash) { |x| %Q{'#{(total_hash[x] || binds[x]).to_s.gsub(/'/, "''")}'} }
    end
  end

  #
  # Quote a single item using a consistent quoting method.
  #
  def quote(item)
    "\'#{item.to_s}\'"
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
