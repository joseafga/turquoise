require "http/server"
require "./turquoise/app"
require "./turquoise/commands/**"
require "./turquoise/cli"

module Turquoise
  server = HTTP::Server.new([
    PubSubHubbub::ErrorHandler.new,
    HTTP::LogHandler.new,
    HTTP::CompressHandler.new,
    PubSubHubbub::SubscriberHandler(PubSubHubbub::Subscriber).new,
  ]) do |context|
    Helpers.handle_webhook(context)
  end

  # Configure telegram webhook
  spawn do
    Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])
  end

  address = server.bind_tcp ENV["SERVER_PORT"].to_i
  Log.info { "Listening on http://#{address}" }
  server.listen
end
