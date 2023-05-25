# A handler that invokes the next handler and, if that next handler raises
# an exception, returns a status code according to the PubSubHubbub.
#
# This handler also logs the exceptions to the specified logger or
# the logger for the source "http.server" by default.
#
# Based on `HTTP::ErrorHandler`
#
# NOTE: To use `ErrorHandler`, you must explicitly import it with `require "http"`
module PubSubHubbub
  class ErrorHandler
    include HTTP::Handler

    def respond_error(response, status : HTTP::Status)
      unless response.closed? || response.wrote_headers?
        response.reset
        response.headers["User-Agent"] = Turquoise::USERAGENT
        response.content_type = "text/plain"
        response.status = status
        response << response.status.code << ' ' << response.status.description << '\n'
        response.close
      end
    end

    def call(context) : Nil
      call_next(context)
    rescue ex : HTTP::Server::ClientError
      Turquoise::Log.debug(exception: ex.cause) { ex.message }
    rescue ex : ChallengeError
      # If the subscriber does not agree with the action, the subscriber MUST respond with a
      # 404 "Not Found" response.

      Turquoise::Log.error(exception: ex) { ex.message }
      respond_error context.response, HTTP::Status::NOT_FOUND
    rescue ex : NotificationError
      # The successful response from the subscriber's callback URL MUST be an HTTP [RFC2616]
      # success (2xx) code. The hub MUST consider all other subscriber response codes as
      # failures; that means subscribers MUST NOT use HTTP redirects for moving subscriptions.
      # The response body from the subscriber MUST be ignored by the hub. Hubs SHOULD retry
      # notifications repeatedly until successful (up to some reasonable maximum over a
      # reasonable time period). Subscribers SHOULD respond to notifications as quickly as
      # possible; their success response code SHOULD only indicate receipt of the message, not
      # acknowledgment that it was successfully processed by the subscriber.

      Turquoise::Log.error(exception: ex) { ex.message }
      respond_error context.response, HTTP::Status::NO_CONTENT
    rescue ex : Exception
      Turquoise::Log.error(exception: ex) { "Unhandled exception" }
      respond_error context.response, HTTP::Status::INTERNAL_SERVER_ERROR
    end
  end
end
