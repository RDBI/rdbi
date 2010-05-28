class RDBI::Statement
  extend MethLab

  attr_reader :dbh
  attr_reader :query
  attr_reader :last_result
  attr_reader :mutex

  inline(:finished, :finished?)   { @finished        }
  inline(:driver)                 { dbh.driver       }
  inline(:finish)                 { @finished = true }

  inline(:last_result, :execute) do |*args|
    raise NoMethodError, "this method is not implemented in this driver"
  end

  def initialize(query, dbh)
    @query = query
    @dbh   = dbh
    @mutex = Mutex.new
    @finished = false
  end

  def execute(*binds)
    raise StandardError, "you may not execute a finished handle" if @finished
    return *binds # XXX FOR NOW
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
