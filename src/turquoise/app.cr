require "log"
require "dotenv"
require "tourmaline"
require "pubsubhubbub"
require "pg"
require "redis"
require "mosquito"

Log.setup_from_env
Dotenv.load? ".env"
Granite::Connections << Granite::Adapter::Pg.new(name: "pg", url: ENV["DATABASE_URL"])

require "granite"
require "granite/adapter/pg"
require "./ext/pubsubhubbub/subscriber"
require "./helpers"
require "./hooks"
require "./eloquent"
require "./models/*"

# TODO: Write documentation for `Turquoise`
module Turquoise
  VERSION   = "0.2.0"
  USERAGENT = "Turquoise/#{VERSION}"
  Log       = ::Log.for("turquoise.app")
  Redis     = ::Redis::Client.new(URI.parse(ENV["REDIS_URL"]))
  Bot       = Tourmaline::Client.new(ENV["BOT_TOKEN"])

  Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])

  PubSubHubbub.configure do |settings|
    settings.host = ENV["HOST_URL"]
    settings.path = ENV["HUB_WEBHOOK_PATH"]
    settings.useragent = USERAGENT
  end

  Mosquito.configure do |settings|
    settings.redis_url = ENV["REDIS_URL"]
  end
end

require "./jobs/**"
