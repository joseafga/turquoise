require "mosquito"
require "tourmaline"
require "dotenv"
require "redis"
require "pg"

Dotenv.load? ".env"
Granite::Connections << Granite::Adapter::Pg.new(name: "pg", url: ENV["DATABASE_URL"])

require "granite"
require "granite/adapter/pg"
require "./pubsubhubbub"
require "./ext/pubsubhubbub/subscriber"
require "./helpers"
require "./hooks"
require "./models/*"

# TODO: Write documentation for `Turquoise`
module Turquoise
  VERSION   = "0.1.0"
  USERAGENT = "Turquoise/#{VERSION}"
  Log       = ::Log.for("turquoise")
  Redis     = ::Redis::Client.new(URI.parse(ENV["REDIS_URL"]))
  Bot       = Tourmaline::Client.new(ENV["BOT_TOKEN"])

  Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])

  PubSubHubbub.configure do |settings|
    settings.host = ENV["HOST_URL"]
    settings.path = ENV["HUB_WEBHOOK_PATH"]
  end

  Mosquito.configure do |settings|
    settings.redis_url = ENV["REDIS_URL"]
  end
end

require "./jobs/**"
