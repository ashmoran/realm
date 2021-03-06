require 'spec_helper'

require 'realm/systems/id_access/domain/events'
require 'realm/systems/id_access/domain/user'

module Realm
  module Systems
    module IdAccess
      module Domain
        describe User do
          describe "construction" do
            subject(:user) {
              User.create(username: "new_username", email_address: "email@example.com")
            }

            before(:each) do
              allow(Realm).to receive(:uuid) { :generated_uuid }
            end

            it "has an uncommitted :user_registered event" do
              expect(user).to have_uncommitted_events(
                {
                  message_type_name:  :user_created,
                  uuid:               :generated_uuid,
                  username:           "new_username",
                  email_address:      "email@example.com"
                }
              )
            end
          end

          describe "#change_password" do
            let(:cryptographer) {
              double("Cryptagrapher", encrypt_password: { opaque: "password description" })
            }

            let(:user_events) {
              [
                Events.build(:user_created,
                  uuid: :user_uuid, username: "username", email_address: "email@example.com"
                )
              ]
            }

            subject(:user) { User.load_from_history(user_events) }

            before(:each) do
              user.change_password("new password", cryptographer: cryptographer)
            end

            it "encrypts the password" do
              expect(cryptographer).to have_received(:encrypt_password).with("new password")
            end

            it "changes the password" do
              expect(user).to have_uncommitted_events(
                { message_type_name: :password_changed, encrypted_password: { opaque: "password description" } }
              )
            end
          end
        end
      end
    end
  end
end
