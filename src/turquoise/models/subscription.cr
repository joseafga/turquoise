module Turquoise
  module Models
    class Subscription < Granite::Base
      table subscriptions

      belongs_to :user
      belongs_to :chat

      column id : Int64, primary: true
      column topic : String?
      column is_active : Bool = true

      timestamps

      validate :topic, "ID de canal inválido" do |subscription|
        !subscription.topic.to_s.match(/^[\w-]{24}$/).nil?
      end

      # Check if topic notification is already active in any chat
      def active?
        self.class.exists? topic: topic, is_active: true
      end

      # Check if notificion is already active on chat by any user
      def exists?
        self.class.exists? chat_id: chat.id, topic: topic, is_active: true
      end
    end
  end
end
