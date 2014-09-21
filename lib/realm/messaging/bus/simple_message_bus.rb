require 'celluloid'

module Realm
  module Messaging
    module Bus
      class NoResultFactoryAvailableError < MessagingError; end

      class NullResultFactory
        def new_unresolved_result(*)
          raise NoResultFactoryAvailableError.new("A MessageBus must be constructed with a ResultFactory to send messages that require a response")
        end
      end

      class SimpleMessageBus
        include MessageBus
        include Celluloid

        class TooManyMessageHandlersError < MessagingError; end

        def initialize(
            result_factory:         NullResultFactory.new,
            unhandled_send_handler: UnhandledMessageSentinel.new
          )

          @result_factory = result_factory

          @handlers = Hash.new { |hash, key| hash[key] = [ ] }
          @unhandled_send_handler = unhandled_send_handler

          @subsystem_routes = Hash.new
        end

        def register(message_type_name, *handlers)
          @handlers[message_type_name.to_sym].concat(handlers)
          Actor.current
        end

        def route_messages_for_subsystem(subsystem_name, to_message_bus:)
          @subsystem_routes[subsystem_name] = to_message_bus
        end

        # Send to a single registered handler
        # It would probably be much better if we just prevented registering multiple handlers
        # for messages of certain types (or add message categories, and make this apply to all
        # command category messages)
        def send(message)
          if @subsystem_routes.has_key?(message.system_name)
            route_message(message, delivery_type: :send)
          else
            send_message(message)
          end
        end

        # Broadcast to all registered handlers
        # This will route messages to configured subsystems, although having
        # impemented that I'm now questioning its validity
        def publish(message)
          if @subsystem_routes.has_key?(message.system_name)
            route_message(message, delivery_type: :publish)
          else
            publish_message(message)
          end

          nil
        end

        private

        def route_message(message, delivery_type:)
          @subsystem_routes[message.system_name].__send__(delivery_type, message)
        end

        def publish_message(message)
          message_type_name = message.message_type_name

          if have_handlers_for?(message_type_name)
            publish_message_to_handlers(message, handlers_for_message_type(message_type_name))
          else
            publish_message_to_unhandled_message_handlers(message)
          end

          nil
        end

        def send_message(message)
          result =
            begin
              @result_factory.new_unresolved_result(message)
            rescue NoResultFactoryAvailableError => e
              abort e
            end

          message_type_name = message.message_type_name
          explicit_handlers = explicit_handlers_for_message_type(message_type_name)

          if explicit_handlers.length == 0
            @unhandled_send_handler.handle_unhandled_message(message)
          elsif explicit_handlers.length == 1
            receiver_for_handler(explicit_handlers.first).send(:"handle_#{message.message_type_name}", message, response_port: result)
          else
            abort TooManyMessageHandlersError.new(
              %'Found #{explicit_handlers.length} message handlers for "#{message_type_name}": #{explicit_handlers.inspect}'
            )
          end

          publish_message_to_handlers(message, handlers_for_all_messages)

          result
        end

        def publish_message_to_handlers(message, handlers)
          handlers.each do |handler|
            publish_message_to_handler(message, handler)
          end
        end

        def publish_message_to_handler(message, handler)
          receiver_for_handler(handler).send(:"handle_#{message.message_type_name}", message)
        end

        def publish_message_to_unhandled_message_handlers(message)
          @handlers[:unhandled_message].each do |handler|
            handler.handle_unhandled_message(message)
          end
        end

        def have_handlers_for?(message_type_name)
          handlers_for_message_type(message_type_name).length > 0
        end

        def handlers_for_message_type(message_type_name)
          explicit_handlers_for_message_type(message_type_name) + handlers_for_all_messages
        end

        def explicit_handlers_for_message_type(message_type_name)
          @handlers[message_type_name]
        end

        def handlers_for_all_messages
          @handlers[:all_messages]
        end

        def receiver_for_handler(handler)
          if handler.respond_to?(:async)
            handler.async
          else
            handler
          end
        end
      end
    end
  end
end
