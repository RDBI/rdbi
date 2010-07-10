#
# RDBI::Statement is the encapsulation of a single prepared statement. A
# statement can be executed with varying arguments multiple times through a
# facility called 'binding'.
#
# == About Binding
#
# Binding is the database term for facilitating placeholder replacement similar
# to formatters such as "sprintf()", but in a database-centric way:
#
#   select * from my_table where some_column = ?
#
# The question mark is the placeholder here; upon execution, the user will be
# asked to provide values to fill that placeholder with.
#
# There are two major advantages to binding:
#
# * Multiple execution of the same statement with variable data
#
# For example, the above statement could be executed 12 times over an iterator:
#
#   # RDBI::Database#prepare creates a prepared statement
#
#   sth = dbh.prepare('select * from my_table where some_column = ?')
#
#   # there is one placeholder here, so we'll use the iterator itself to feed
#   # to the statement at execution time.
#   #
#   # This will send 12 copies of the select statement above, with 0 - 11 being
#   # passed as the substitution for each placeholder. Use
#   # RDBI::Database#preprocess_query to see what these queries would look
#   # like.
#
#   12.times do |x|
#     sth.execute(x)
#   end
#
# * Protection against attacks such as SQL injection in a consistent way (see below).
#
# == Native client binding 
#
# Binding is typically *not* just text replacement, it is a client-oriented
# operation that barely involves itself in the string at all. The query is
# parsed by the SQL engine, then the placeholders are requested; at this point,
# the client yields those to the database which then uses them in the
# *internal* representation of the query, which is why this is totally legal in
# a binding scenario:
#
#   # RDBI::Database#execute is a way to prepare and execute statements immediately.
#   dbh.execute("select * from my_table where some_column = ?", "; drop table my_table;")
#
# For purposes of instruction, this resolves to:
#
#   select * from my_table where some_column = '; drop table my_table;'
#
# *BUT*, as mentioned above, the query is actually sent in two stages. It gets this:
#
#   select * from my_table where some_column = ?
#
# Then a single element tuple is sent:
#
#   ["; drop table my_table;"]
#
# These are combined *post-parsing* to create a full, legal statement, so no
# grammar rules can be exploited.
#
# As a result, placeholder rules in this scenario are pretty rigid, only values
# can be used. For example, you cannot supply placeholders for:
#
# * table names
# * sql keywords and functions
# * other elements of syntax (punctuation, etc)
#
# == Preprocessing
#
# Preprocessing is a fallback mechanism we use when the underlying database 
#
class RDBI::Statement
  extend MethLab

  attr_reader :dbh
  attr_reader :query
  attr_reader :mutex
  attr_reader :input_type_map

  attr_threaded_accessor :last_result

  inline(:finished, :finished?)   { @finished  }
  inline(:driver)                 { dbh.driver }

  inline(:new_execution) do |*args|
    raise NoMethodError, "this method is not implemented in this driver"
  end

  def initialize(query, dbh)
    @query = query
    @dbh   = dbh
    @mutex = Mutex.new
    @finished = false
    @input_type_map = RDBI::Type.create_type_hash(RDBI::Type::In)

    @dbh.open_statements.push(self)
  end

  def execute(*binds)
    raise StandardError, "you may not execute a finished handle" if @finished

    binds = binds.collect { |x| RDBI::Type::In.convert(x, @input_type_map) }

    mutex.synchronize do
      exec_args = *new_execution(*binds)
      self.last_result = RDBI::Result.new(self, binds, *exec_args)
    end
  end

  def finish
    mutex.synchronize do
      dbh.open_statements.reject! { |x| x.object_id == self.object_id }
      @finished = true
    end
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
