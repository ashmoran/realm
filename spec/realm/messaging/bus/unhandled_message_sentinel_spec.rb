require 'spec_helper'

require 'realm/messaging'

module Realm
  module Messaging
    module Bus
      describe UnhandledMessageSentinel do
        let(:message_type) { MessageType.new(:foo, [ :message ]) }
        let(:message_bus) { SimpleMessageBus.new }
        subject(:handler) { UnhandledMessageSentinel.new }

        it "raises an error on unhandled messages" do
          message_bus.register(:unhandled_message, handler)

          expect {
            message_bus.publish(message_type.new_message(uuid: :unused_uuid, message: "bar"))
          }.to raise_error(UnhandledMessageSentinel::UnhandledMessageError) { |error|
            expect(error.message).to include('"foo"')
            expect(error.message).to include("message:")
            expect(error.message).to include("bar")
          }
        end
      end
    end
  end
end