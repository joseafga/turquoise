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

      # Youtube topic validation.
      # Must be something like: *https://www.youtube.com/xml/feeds/videos.xml?channel_id=ABC_1234abcdefgh1234ASDF*
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

        # Updata database when receive a new challenge request
        subscriber.on :challenge do |query|
          params = URI::Params.parse(query)

          case params["hub.mode"]
          when "subscribe"
            update is_active: true
            # Subscription duration is 5 days (120 hours)
            Jobs::RenewSubscription.new(topic: subscriber.topic).enqueue(in: 110.hours)
          when "unsubscribe"
            update is_active: false
          end
        end

        # Notification received, send it to listeners if subscription is active
        subscriber.on :notify do |xml|
          raise "Inactive subscription (#{subscriber.topic})." unless active?

          entry = PubSubHubbub::Feed.parse(xml).entries.first

          # When uploading or updating a video, the notification is equal, a workaround to
          # identify it was store the video id in redis and compare it with the notification.
          found = Redis.sismember("turquoise:subscription:history", entry.id.not_nil!).as(Int64)
          next unless found.zero?
          Redis.sadd "turquoise:subscription:history", entry.id.not_nil!

          message = <<-MSG
          #video #youtube #iute
          #{entry.title}
          #{entry.link}
          MSG

          chats.each do |chat|
            Bot.send_message(chat_id: chat.id!, text: Helpers.escape_md message)
          end
        rescue ex
          Log.error { "Notification - #{ex.message}." }
        end

        subscriber
      end

      # `SubscriberHandler` uses to handle incoming requests from Hub
      def self.find_subscriber!(topic : String?) : PubSubHubbub::Subscriber
        find!(topic).to_subscriber
      end
    end
  end
end
