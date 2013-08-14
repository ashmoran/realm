module Realm
  module Messaging
    class MessageFactory
      class UnknownMessageTypeError < ArgumentError; end

      def initialize(message_type_factory = MessageType, &builder_block)
        @message_type_factory = message_type_factory
        @message_types = Hash.new
        builder_block[self] if block_given?
      end

      def define(message_type_name, definition = { })
        @message_types[message_type_name] = @message_type_factory.new(message_type_name, definition)
      end

      def build(message_type_name, attributes = { })
        message_type = @message_types.fetch(message_type_name) do
          raise UnknownMessageTypeError.new(%Q'Unknown MessageType: "#{message_type_name}"')
        end

        message_type.new_message(attributes)
      end
    end
  end
end
