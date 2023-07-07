require "uri/params"

module Turquoise
  module Models
    class Listener < Granite::Base
      table listeners

      belongs_to user : User
      belongs_to chat : Chat
      belongs_to subscription : Subscription, primary_key: "topic", foreign_key: subscription_topic : String

      column id : Int64, primary: true
      timestamps

      after_destroy :check_subscription

      def check_subscription
        if subscription.chats.empty?
          subscription.unsubscribe
        end
      end

      def self.find_subscriber!(topic : String?)
        find_by!(topic: topic).subscriber
      end
    end
  end
end
