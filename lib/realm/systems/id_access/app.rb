require 'facets/hash/deep_merge'
require 'realm/domain/validation'

module Realm
  module Systems
    module IdAccess
      class App
        def initialize(message_bus:, message_logger: nil,
                       event_store:, query_database:,
                       cryptographer:, config: { })
          @message_bus    = message_bus
          @message_logger = message_logger
          @event_store    = event_store
          @query_database = query_database
          @cryptographer  = cryptographer
          @config         = default_config.deep_merge(config)
        end

        def boot
          # Query models first because command handlers may depend on them
          connect_query_models
          connect_command_handlers
          connect_application_services
          connect_message_logger

          # Allow people to capture the app by calling app = App.new.boot
          self
        end

        def application_services
          @application_services ||= Hash.new
        end

        private

        def connect_command_handlers
          @message_bus.register(:sign_up_user,
            Application::CommandHandlers::SignUpUser.new(
              user_registry: user_registry,
              user_service:  user_service,
              cryptographer: @cryptographer,
              validator:     @config[:commands][:sign_up_user][:validator]
            )
          )
        end

        def connect_query_models
          connect_query_model(:registered_users,
            query_model_class: QueryModels::RegisteredUsers,
            events:           [ :user_created ]
          )
        end

        def connect_application_services
          application_services[:user_service] = user_service
        end

        def connect_message_logger
          if @message_logger
            @message_bus.register(:all_messages, @message_logger)
          end
        end

        # Hijacked from Harvest, maybe we could put this on the message bus?
        # (In normal production use, we want each read model listening to all
        # the events it understands.)
        def connect_query_model(name, query_model_class: r(:query_model_class), events: r(:events))
          query_models[name] =
            query_model_class.new(@query_database[name])

          events.each do |event_name|
            @message_bus.register(event_name, query_models[name])
          end
        end

        def query_models
          @query_models ||= Hash.new
        end

        def user_registry
          @user_registry ||= Domain::UserRegistry.new(@event_store)
        end

        def user_service
          @user_service ||= Domain::UserService.new(registered_users: query_models[:registered_users])
        end

        def default_config
          {
            commands: {
              sign_up_user: {
                validator: Realm::Domain::Validation::CommandValidator.new
              }
            }
          }
        end
      end
    end
  end
end
