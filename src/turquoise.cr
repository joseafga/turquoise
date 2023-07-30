require "option_parser"
require "http/server"
require "./turquoise/app"
require "./turquoise/commands/**"

module Turquoise
  OptionParser.parse do |parser|
    parser.banner = "Telegram bot for YouTube notifications and fun."

    parser.on "--delete-webhook", "Delete Telegram webhook" do
      Log.info { "Deleting Telegram webhook." }
      Bot.delete_webhook
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

  # Configure telegram webhook and send a startup message to owner
  spawn do
    Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])
    Bot.send_message ENV["BOT_OWNER"], text: "Prontinha!"
  end

  server = HTTP::Server.new([
    PubSubHubbub::ErrorHandler.new,
    HTTP::LogHandler.new,
    HTTP::CompressHandler.new,
    PubSubHubbub::SubscriberHandler(PubSubHubbub::Subscriber).new,
  ]) do |context|
    Helpers.handle_webhook(context)
  end

  address = server.bind_tcp ENV["SERVER_PORT"].to_i
  Log.info { "Listening on http://#{address}" }
  server.listen
end
