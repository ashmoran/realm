module Realm
  module Messaging
    module Handlers
      class MessageLogger
        include Celluloid

        def initialize(format_with:, log_to:)
          @formatter  = format_with
          @logger     = log_to
        end

        def method_missing(name, *args, &block)
          if name =~ /^handle_/
            raise_if_arg_length_is_incorrect(1, args.length)
            log_message(args.first)
          else
            super
          end
        end

        def respond_to?(name, include_private = false)
          (name =~ /^handle_/) || super
        end

        private

        def log_message(message)
          @logger.info(
            format_message(message)
          )
        end

        def format_message(message)
          message.output_to(@formatter)
        end

        def raise_if_arg_length_is_incorrect(expected_length, actual_length)
          if actual_length != expected_length
            abort ArgumentError.new("wrong number of arguments (#{actual_length} for #{expected_length})")
          end
        end
      end
    end
  end
end