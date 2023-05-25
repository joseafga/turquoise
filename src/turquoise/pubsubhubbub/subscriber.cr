require "http"
require "uri/params"
require "openssl/hmac"

# Subscriber for PubSubHubbub protocol
# ```
# sub = PubSubHubbub::Subscriber.new(
#   "https://www.youtube.com/xml/feeds/videos.xml?channel_id=SomeChannelId",
#   "https://example.com"
# )
#
# sub.subscribe
# ```
module PubSubHubbub
  class Subscriber
    enum Mode
      Subscribe
      Unsubscribe
    end

    ENDPOINT = "https://pubsubhubbub.appspot.com/subscribe"
    property topic : String, callback : String
    property secret : String | Nil
    @@instances = [] of self

    def initialize(@topic, @callback, @secret = nil)
      @@instances << self
    end

    # Make a request to unsubscribe/subscribe on the YouTube PubSubHubbub publisher
    def request(mode : Mode)
      headers = HTTP::Headers{"User-Agent" => Turquoise::USERAGENT}

      params = URI::Params.build do |hub|
        hub.add "hub.topic", @topic
        hub.add "hub.callback", @callback
        hub.add "hub.mode", mode.to_s.downcase
        hub.add "hub.secret", @secret unless @secret.nil?
      end

      # PubSubHubbub will request a challenge for callback after post request
      HTTP::Client.post(ENDPOINT, headers: headers, form: params) do |res|
        Turquoise::Log.info { "#{res.status_code} #{res.status_message} - #{mode} on #{@topic} -> #{@callback}" }
      end
    end

    def subscribe
      request Mode::Subscribe
    end

    def unsubscribe
      request Mode::Unsubscribe
    end

    # When subscribers receive a content distribution request with the X-Hub-Signature
    # header specified, they SHOULD recompute the SHA1 signature with the shared secret
    # using the same method as the hub. If the signature does not match, subscribers MUST
    # still return a 2xx success response to acknowledge receipt, but locally ignore the
    # message as invalid.
    def check_signature(signature : String, body : String?)
      return if @secret.nil?

      algo, sig = signature.split('=')
      unless algo.compare("sha1", case_insensitive: true).zero?
        raise NotificationError.new "X-Hub-Signature should be SHA1"
      end

      hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Algorithm::SHA1, @secret.to_s, body.to_s)
      unless hmac.compare(sig, case_insensitive: true).zero?
        raise NotificationError.new "X-Hub-Signature does not match"
      end
    end

    # The subscriber MUST confirm that the hub.topic corresponds to a pending subscription or
    # unsubscription that it wishes to carry out. If so, the subscriber MUST respond with an
    # HTTP success (2xx) code with a response body equal to the hub.challenge parameter.
    def challenge_verification(response : HTTP::Server::Response, params : HTTP::Params)
      raise ChallengeError.new "Invalid challenge" unless params["hub.challenge"]?

      response.content_type = "text/plain"
      response.status = HTTP::Status::OK
      response.print params["hub.challenge"]
    end

    def self.find_instance(topic : String?)
      @@instances.each do |instance|
        return instance if instance.topic == topic.to_s
      end
      raise "No related topic"
    end
  end
end
