# Handle requests from the hub.
#
# ```
# require "http"
#
# server = HTTP::Server.new([
#   PubSubHubbub::SubscriberHandler(MySubscriber).new,
# ])
#
# address = server.bind_tcp 8080
# puts "Listening on http://#{address}"
# server.listen
# ```
module PubSubHubbub
  class SubscriberHandler(T)
    include HTTP::Handler

    def call(context) : Nil
      unless context.request.path == PubSubHubbub.config.path
        call_next(context)
        return
      end

      # Check if is a verification or notification
      case context.request.method
      when "GET"
        # The subscriber MUST confirm that the hub.topic corresponds to a pending subscription or
        # unsubscription that it wishes to carry out. If so, the subscriber MUST respond with an
        # HTTP success (2xx) code with a response body equal to the hub.challenge parameter.
        begin
          Turquoise::Log.debug { "Challenge - #{context.request.query_params["hub.mode"]} on #{context.request.query_params["hub.topic"]}" }
          subscriber = T.find_subscriber!(context.request.query_params["hub.topic"])
          answer = subscriber.challenge_verification(context.request.query_params)

          context.response.content_type = "text/plain"
          context.response.status = HTTP::Status::OK
          context.response.print answer
          subscriber.emit :challenge, context.request.query_params.to_s
        rescue ex
          raise ChallengeError.new ex.message
        end
      when "POST"
        # When subscribers receive a content distribution request with the X-Hub-Signature
        # header specified, they SHOULD recompute the SHA1 signature with the shared secret
        # using the same method as the hub. If the signature does not match, subscribers MUST
        # still return a 2xx success response to acknowledge receipt, but locally ignore the
        # message as invalid.
        begin
          if body = context.request.body.try &.gets_to_end
            raise "No content was delivered" if body.nil?
            
            Turquoise::Log.debug { "Notification - #{body}" }
            subscriber = T.find_subscriber!(Feed.parse_topic(body))
            subscriber.check_signature(context.request.headers["X-Hub-Signature"], body)

            context.response.status = HTTP::Status::NO_CONTENT
            subscriber.emit :notify, body
          end
        rescue ex
          raise NotificationError.new ex.message
        end
      else
        raise "Invalid HTTP method `#{context.request.method}`"
      end

      context.response.headers["User-Agent"] = Turquoise::USERAGENT
    end
  end
end
