require "./turquoise/app"
require "./turquoise/commands/**"
require "http/server"

module Turquoise
  # Configure telegram webhook and send a startup message to owner
  spawn do
    Helpers.config_webhook
    Bot.send_message(ENV["BOT_OWNER"], text: "Prontinha!")
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
