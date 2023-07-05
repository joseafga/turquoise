module Turquoise
  module Models
    class Subscription < Granite::Base
      table subscriptions

      belongs_to :user
      belongs_to :chat

      column id : Int64, primary: true
      column topic : String
      column is_active : Bool = true

      timestamps

      # Youtube topic validation
      validate :topic, "Identificador de canal inválido" do |subscription|
        !subscription.topic.to_s.delete_at(..55).match(/^[\w-]{24}$/).nil?
      end

      # Check if topic notification is already active in any chat
      def active?
        self.class.exists? topic: topic, is_active: true
      end

      # Check if notificion is already active on chat by any user
      def exists?
        self.class.exists? chat_id: chat.id, topic: topic, is_active: true
      end

      def subscriber
        subscriber = PubSubHubbub::Subscriber.new(topic, secret: ENV["HUB_SECRET"]?)

        subscriber.on :challenge do
          Bot.send_message(chat_id: chat.id.not_nil!, text: "Inscrito com sucesso. 🫡")
        end

        subscriber.on :notify do |xml|
          next if xml.nil?
          entry = PubSubHubbub::Feed.parse(xml).entries.first
          message = <<-MSG
          #video #yt #iute
          #{entry.title}
          #{entry.link}
          MSG

          Bot.send_message(chat_id: chat.id.not_nil!, text: Helpers.escape_md message)
        end

        subscriber
      end

      def self.find_subscriber!(topic : String?)
        find_by!(topic: topic, is_active: true).subscriber
      end
    end
  end
end
