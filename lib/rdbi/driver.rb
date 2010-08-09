#
# RDBI::Driver is the bootstrap handle to yield database connection
# (RDBI::Database) handles. It preserves the connection parameters and the
# desired database, and outside of yielding handles, does little else.
#
# As such, it is normally intended to be used by RDBI internally and (rarely
# by) Database drivers.
#
class RDBI::Driver
  # connection arguments requested during initialization
  attr_reader :connect_args
  # Database driver class requested for initialization
  attr_reader :dbh_class

  # Initialize a new driver object. This accepts an RDBI::Database subclass as a
  # class name (shorthand does not work here) and the arguments to pass into
  # the constructor.
  def initialize(dbh_class, *args)
    @dbh_class = dbh_class
    @connect_args = [RDBI::Util.key_hash_as_symbols(args[0])]
  end

  #
  # This is a proxy method to construct RDBI::Database handles. It constructs
  # the RDBI::Database object, and sets the driver on the object to this
  # current object for duplication / multiple creation.
  #
  def new_handle 
    dbh = @dbh_class.new(*@connect_args)
    dbh.driver = self
    return dbh
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
