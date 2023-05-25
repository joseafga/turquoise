require "dotenv"
require "tourmaline"
require "./turquoise/pubsubhubbub"
require "./turquoise/bot"

Dotenv.load? ".env"

# TODO: Write documentation for `Turquoise`
module Turquoise
  VERSION   = "0.1.0"
  USERAGENT = "Turquoise/#{VERSION}"
  Log       = ::Log.for("turquoise")

  Subscriber = PubSubHubbub::Subscriber.new(
    "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ENV["HUB_CHANNEL_ID"]}",
    ENV["HUB_CALLBACK"],
    ENV["HUB_SECRET"]?
  )
end


###### TODO
# spawn do
# sub.subscribe
# server = HTTP::Server.new([
#   PubSubHubbub::ErrorHandler.new,
#   HTTP::LogHandler.new,
#   PubSubHubbub::SubscriberHandler.new do |xml|
#     feed = Feed.parse(xml.to_s)
#     puts feed.entries.first.published
#   end,
#   HTTP::CompressHandler.new,
# ])

# address = server.bind_tcp ENV["PORT"].to_i
# Turquoise::Log.info { "Listening on http://#{address}" }
# server.listen
# end

# sleep 0.1

bot = Turquoise::Bot.new(ENV["BOT_TOKEN"])
bot.register_commands

bot.on :update do |ctx|
  puts ctx.text
end

spawn do
  bot.send_message(ENV["BOT_OWNER"], text: "Estou pronta!")
end

bot.poll
