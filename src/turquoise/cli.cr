require "option_parser"
require "http/server"

module Turquoise
  module CLI
    extend self

    class_setter server : HTTP::Server?
    class_property server_port = 3000
    class_property welcome_chat = ENV["BOT_OWNER"]
    class_property welcome_message = "Ready!"
    class_property? poller = true

    private def server : HTTP::Server
      @@server ||= HTTP::Server.new([
        PubSubHubbub::ErrorHandler.new,
        HTTP::LogHandler.new,
        HTTP::CompressHandler.new,
        PubSubHubbub::SubscriberHandler(PubSubHubbub::Subscriber).new,
      ]) do |context|
        Helpers.handle_webhook(context)
      end
    end

    def run
      OptionParser.parse do |parser|
        parser.banner = "Telegram bot for YouTube notifications and fun."

        parser.on "-c CHAT", "--chat=CHAT", "Welcome message chat id" do |chat|
          @@welcome_chat = chat
        end
        parser.on "-m MSG", "--message=MSG", "Welcome message text" do |msg|
          @@welcome_message = msg
        end
        parser.on "-p PORT", "--port=PORT", "Webhook server port" do |port|
          @@server_port = port.to_i
        end
        parser.on "--delete-webhook", "Delete Telegram webhook" do
          Log.info { "Deleting Telegram webhook." }
          Bot.delete_webhook
        end
        parser.on "--webhook", "Use bot webhook instead of puller" do
          @@poller = false
        end
        parser.on "-h", "--help", "Show help" do
          puts parser
          exit
        end
        parser.on "-v", "--version", "Show version" do
          puts "version #{VERSION}"
          exit
        end
      end

      if poller?
        Bot.poll
      else
        Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])
        address = server.bind_tcp server_port
        Log.info { "Listening on http://#{address}" }
        server.listen
      end
    end

    def send_welcome
      Bot.send_message welcome_chat, text: welcome_message
    end
  end
end
