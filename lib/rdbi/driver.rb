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

# vim: syntax=ruby ts=2 et sw=2 sts=2
