require "./turquoise/app"
require "./turquoise/commands/**"
require "http"

module Turquoise
  # TODO: Startup message to owner
  # bot.send_message(ENV["BOT_OWNER"], text: "Prontinha!")

  server = HTTP::Server.new([
    PubSubHubbub::ErrorHandler.new,
    HTTP::LogHandler.new,
    HTTP::CompressHandler.new,
    PubSubHubbub::SubscriberHandler(Models::Subscription).new,
  ]) do |context|
    Helpers.handle_webhook(context)
  end

  address = server.bind_tcp ENV["SERVER_PORT"].to_i
  Log.info { "Listening on http://#{address}" }
  server.listen
end
