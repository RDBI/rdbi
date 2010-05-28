module RDBI
  class Driver
    class Mock < RDBI::Driver
      def initialize(*args)
        super(Mock::DBH, *args)
      end
    end

    # XXX STUB
    class Mock::STH < RDBI::Statement
      attr_accessor :result

      def initialize(query, dbh)
        super
      end

      # FIXME rework when result stuff is done.
      #
      # just to be abundantly clear, this is a mock method intended to
      # facilitate tests.
      def execute(*binds)
        super
        mutex.synchronize do
          @last_result = if result
                           result
                         else
                           (0..4).to_a.collect do |x|
                             binds.collect do |bind|
                               case bind
                               when Integer
                                 bind + x
                               else
                                 bind.to_s + x.to_s
                               end
                             end
                           end
                         end
        end

        return @last_result
      end
    end

    class Mock::DBH < RDBI::Database
      extend MethLab

      attr_accessor :next_action

      def new_statement(query)
        Mock::STH.new(query, self)
      end

      def ping
        10
      end

      inline(:rollback) { super; "rollback called" }

      # XXX more methods to be defined this way.
      inline(:commit) do |*args|
        super(*args)

        ret = nil

        if next_action
          ret = next_action.call(*args)
          self.next_action = nil
        end

        ret
      end
    end
  end
end

# vim: syntax=ruby ts=2 et sw=2 sts=2
