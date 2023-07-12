require "log"
require "dotenv"
require "tourmaline"
require "pubsubhubbub"
require "pg"
require "redis"
require "mosquito"

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
  VERSION   = "0.2.2"
  USERAGENT = "Turquoise/#{VERSION}"
  Log       = ::Log.for("turquoise.app")
  Redis     = ::Redis::Client.new(URI.parse(ENV["REDIS_URL"]))
  Bot       = Tourmaline::Client.new(ENV["BOT_TOKEN"])

  ::Log.setup_from_env
  ::Log.setup do |c|
    backend = ::Log::IOBackend.new

    c.bind "*", :warn, backend
    c.bind "tourmaline.*", :info, backend
    c.bind "mosquito.*", :info, backend
    c.bind "turquoise.*", :debug, backend
  end

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
