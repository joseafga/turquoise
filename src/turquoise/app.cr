require "mosquito"
require "tourmaline"
require "dotenv"
require "pg"

Dotenv.load? ".env"
Granite::Connections << Granite::Adapter::Pg.new(name: "pg", url: ENV["DATABASE_URL"])

require "granite"
require "granite/adapter/pg"
require "./helpers"
require "./models/*"
require "./pubsubhubbub"

# TODO: Write documentation for `Turquoise`
module Turquoise
  VERSION    = "0.1.0"
  USERAGENT  = "Turquoise/#{VERSION}"
  Log        = ::Log.for("turquoise")
  Bot        = Tourmaline::Client.new(ENV["BOT_TOKEN"])
  Subscriber = PubSubHubbub::Subscriber.new(
    "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ENV["HUB_CHANNEL_ID"]}",
    ENV["HUB_CALLBACK"],
    ENV["HUB_SECRET"]?
  )

  Mosquito.configure do |settings|
    settings.redis_url = ENV["REDIS_URL"]
  end
end

require "./jobs/**"
