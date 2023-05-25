# Handle requests from the hub
#
# ```
# require "http"
#
# server = HTTP::Server.new([
#   PubSubHubbub::SubscriberHandler.new do |xml|
#     puts xml
#   end,
# ])
#
# address = server.bind_tcp 8080
# puts "Listening on http://#{address}"
# server.listen
# ```
module PubSubHubbub
  class SubscriberHandler
    include HTTP::Handler

    # Initialize without a block. It will be able to do verification challenge but will do
    # nothing with hub notifications
    def initialize
      @notification = nil
    end

    # Every new notification from the hub will be passed for the block as xml
    def initialize(&@notification : String ->)
    end

    def call(context) : Nil
      req = context.request
      res = context.response
      res.headers["User-Agent"] = Turquoise::USERAGENT

      # Check if is a verification or notification
      case req.method
      when "GET"
        begin
          instance = Subscriber.find_instance(req.query_params["hub.topic"])
          instance.challenge_verification(res, req.query_params)
        rescue ex
          raise ChallengeError.new ex.message
        end
      when "POST"
        begin
          body = req.body.try &.gets_to_end
          raise "No content was delivered" if body.nil?

          instance = Subscriber.find_instance(Feed.parse_topic(body))
          instance.check_signature(req.headers["X-Hub-Signature"], body)

          res.status = HTTP::Status::NO_CONTENT
          @notification.try &.call(body)
        rescue ex
          raise NotificationError.new ex.message
        end
      else
        raise "Invalid HTTP method `#{req.method}`"
      end
    end
  end
end
