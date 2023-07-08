module PubSubHubbub
  class Subscriber
    property subscription : Turquoise::Models::Subscription?

    def to_subscription
      @subscription ||= Turquoise::Models::Subscription.find!(topic)
    end

    # `SubscriberHandler` uses to handle incoming requests from Hub
    def self.find_subscriber!(topic : String?) : Subscriber
      Turquoise::Models::Subscription.find!(topic).to_subscriber
    end
  end
end
