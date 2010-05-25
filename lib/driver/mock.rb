module RDBI
    module Driver
        class Mock
            class DBH < RDBI::Database
                def ping
                    10
                end
            end

            def initialize(*args)
                @connect_args = args
            end

            def get_handle
                return DBH.new(*@connect_args)
            end
        end
    end
end

# vim: syntax=ruby ts=4 et sw=4 sts=4
