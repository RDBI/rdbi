class RDBI::Database
    extend MethLab

    # the driver class that is responsible for creating this database handle.
    attr_accessor :driver

    # are we currently in a transaction?
    attr_reader :in_transaction

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
            :transaction, 
            :table_schema, 
            :schema,
            :last_statement
          ) { |*args| raise NoMethodError, "this method is not implemented in this driver" }

    inline(:commit, :rollback) { @in_transaction = false }

    def initialize(*args)
        # FIXME symbolify
        @connect_args = args[0]
        @connected    = true
        @mutex        = Mutex.new
    end

    def transaction(&block)
        mutex.synchronize do
            @in_transaction = true
            begin
                yield self
                commit if @in_transaction
            rescue
                rollback 
            ensure
                @in_transaction = false
            end
        end
    end

    def prepare(query)
        @last_query = query
    end

    def execute(query, *binds)
        @last_query = query
    end

    def preprocess_query(query, *binds)
        @last_query = query
        ep = Epoxy.new(query)
        ep.quote { |x| %Q{'#{binds[x].gsub(/'/, "''")}'} }
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
