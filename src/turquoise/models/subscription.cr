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
        to_subscriber.subscribe
      end

      def unsubscribe
        to_subscriber.unsubscribe
      end

      def to_subscriber
        PubSubHubbub::Subscriber.new(topic!, secret: @secret)
      end
    end
  end
end
