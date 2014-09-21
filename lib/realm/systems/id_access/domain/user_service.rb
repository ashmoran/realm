module Realm
  module Systems
    module IdAccess
      module Domain
        # Is this actually an Application Service?
        class UserService
          def initialize(registered_users:)
            @registered_users = registered_users
          end

          def username_available?(username)
            !@registered_users.record_for(username: username)
          end

          def email_address_available?(email_address)
            !@registered_users.record_for(email_address: email_address)
          end
        end
      end
    end
  end
end
