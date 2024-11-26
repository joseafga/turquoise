module Turquoise
  # Updata database when receive a new challenge request
  PubSubHubbub::Subscriber.on :challenge do |subscriber, query|
    params = URI::Params.parse(query)

    case params["hub.mode"]
    when "subscribe"
      subscriber.to_subscription.update is_active: true
      # Subscription duration is 5 days (120 hours)
      Jobs::RenewSubscription.new(topic: subscriber.topic).enqueue(in: 110.hours)
    when "unsubscribe"
      subscriber.to_subscription.update is_active: false
    end
  end

  # Notification received, send it to listeners if subscription is active
  PubSubHubbub::Subscriber.on :notify do |subscriber, xml|
    raise "Inactive subscription (#{subscriber.topic})." unless subscriber.to_subscription.active?
    entry = PubSubHubbub::Feed.parse(xml).entries.first

    # When uploading or updating a video, the notification is equal, a workaround to identify it was store the video id
    # in redis and compare it with the notification.
    found = Redis.sismember("turquoise:subscription:history", entry.id.not_nil!).as(Int64)
    next unless found.zero?
    Redis.sadd "turquoise:subscription:history", entry.id.not_nil!

    subscriber.to_subscription.chats.each do |chat|
      Bot.send_message chat_id: chat.id!, text: Helpers.escape_md <<-MSG
      #video #youtube #iute
      #{entry.title}
      #{entry.link}
      MSG
    end
  rescue ex
    Log.error { "Notification - #{ex.message}." }
  end
end
