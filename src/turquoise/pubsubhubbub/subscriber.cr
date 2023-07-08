require "http"
require "uri/params"
require "openssl/hmac"

# Subscriber for PubSubHubbub protocol.
# ```
# sub = PubSubHubbub::Subscriber.new(
#   "https://www.youtube.com/xml/feeds/videos.xml?channel_id=SomeChannelId",
#   "https://example.com"
# )
#
# sub.subscribe
# ```
module PubSubHubbub
  enum Event
    Subscribe
    Unsubscribe
    Challenge
    Notify
  end

  class Subscriber
    enum Mode
      Subscribe
      Unsubscribe
    end

    property topic : String
    property secret : String?
    class_getter hooks = {} of Event => Array(Proc(Subscriber, String, Nil))

    def initialize(@topic, @secret = nil)
    end

    # Make a request to unsubscribe/subscribe on the YouTube PubSubHubbub publisher.
    def request(mode : Mode)
      headers = HTTP::Headers{"User-Agent" => Turquoise::USERAGENT}

      params = URI::Params.build do |hub|
        hub.add "hub.topic", @topic
        hub.add "hub.callback", PubSubHubbub.config.callback
        hub.add "hub.mode", mode.to_s.downcase
        hub.add "hub.secret", @secret unless @secret.nil?
      end

      # PubSubHubbub will request a challenge for callback after post request.
      HTTP::Client.post(PubSubHubbub.config.endpoint, headers: headers, form: params) do |res|
        Turquoise::Log.debug { "#{res.status_code} #{res.status_message} - #{mode} on #{@topic} -> #{PubSubHubbub.config.callback}" }
      end
    end

    def subscribe
      emit Event::Subscribe
      request Mode::Subscribe
    end

    def unsubscribe
      emit Event::Subscribe
      request Mode::Unsubscribe
    end

    # Recompute the SHA1 signature with the shared secret using the same method as the hub.
    def check_signature(signature : String, body : String?)
      unless @secret.nil?
        algo, sig = signature.split('=')
        unless algo.compare("sha1", case_insensitive: true).zero?
          raise NotificationError.new "X-Hub-Signature should be SHA1"
        end

        hmac = OpenSSL::HMAC.hexdigest(OpenSSL::Algorithm::SHA1, @secret.to_s, body.to_s)
        unless hmac.compare(sig, case_insensitive: true).zero?
          raise NotificationError.new "X-Hub-Signature does not match"
        end
      end
    end

    # Check if hub.challenge exists and return them.
    def challenge_verification(params : HTTP::Params)
      raise ChallengeError.new "Invalid challenge" unless params["hub.challenge"]?

      params["hub.challenge"]
    end

    def emit(event : Event, data : String? = nil)
      self.class.emit(self, event, data)
    end

    # Send signal to call functions attached to corresponding `Event`
    def self.emit(subscriber : Subscriber, event : Event, data : String? = nil)
      return unless @@hooks.has_key?(event)

      @@hooks[event].each do |block|
        block.call(subscriber, data.to_s)
      end
    end

    # Attach a block (function) to a specific 'Event', when the event occurs, the function
    # will be called.
    def self.on(event : Event, &block : Subscriber, String ->)
      @@hooks[event] ||= [] of Proc(Subscriber, String, Nil)
      @@hooks[event] << block
    end
  end
end
