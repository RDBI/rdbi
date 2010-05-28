class RDBI::Result
    include Enumerable

    inline(
        :[],
        :complete?,
        :has_data?,
        :eof?,
        :rewind,
        :rows,
        :binds,
        :as,
        :fetch,
        :raw_fetch,
        :finish,
        :sth,
        :schema,
        :each
    ) { raise NoMethodError, "not done yet" }

    def initialize(data, sth, binds)
        @data  = data
        @sth   = sth
        @binds = binds
        @index = 0
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
