module Turquoise
  module Models
    class Subscription < Granite::Base
      table subscriptions

      has_many listeners : Listener, foreign_key: :subscription_topic
      has_many users : User, through: :listeners, foreign_key: :subscription_topic
      has_many chats : Chat, through: :listeners, foreign_key: :subscription_topic

      column topic : String, primary: true, auto: false
      column secret : String? = ENV["HUB_SECRET"]
      column is_active : Bool = false
      timestamps

      after_create :subscribe
      before_destroy :unsubscribe

      # Youtube topic validation
      validate :topic, "Identificador de canal inválido" do |subscription|
        !subscription.topic.to_s.delete_at(..55).match(/^[\w-]{24}$/).nil?
      end

      def active?
        is_active
      end

      def subscribe
        PubSubHubbub::Subscriber.new(topic!, secret: secret).subscribe
      end

      def unsubscribe
        PubSubHubbub::Subscriber.new(topic!, secret: secret).unsubscribe
      end

      def to_subscriber
        subscriber = PubSubHubbub::Subscriber.new(topic!, secret: secret)

        # Updata database when receive the challenge
        subscriber.on :challenge do |query|
          params = URI::Params.parse(query)

          case params["hub.mode"]
          when "subscribe"
            update is_active: true
            # TODO: create job to renew
          when "unsubscribe"
            update is_active: false
          end
        end

        # Notification received, send to listeners
        subscriber.on :notify do |xml|
          next unless active?

          entry = PubSubHubbub::Feed.parse(xml).entries.first
          message = <<-MSG
          #video #youtube #iute
          #{entry.title}
          #{entry.link}
          MSG

          chats.each do |chat|
            Bot.send_message(chat_id: chat.id!, text: Helpers.escape_md message)
          end
        end

        subscriber
      end

      def self.find_subscriber!(topic : String?) : PubSubHubbub::Subscriber
        find!(topic).to_subscriber
      end
    end
  end
end
