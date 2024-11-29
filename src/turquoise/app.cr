require "log"
require "dotenv"
require "tourmaline"
require "pubsubhubbub"
require "gemini"
require "pg"
require "redis"
require "mosquito"

Dotenv.load? ".env"
Granite::Connections << Granite::Adapter::Pg.new(name: "pg", url: ENV["DATABASE_URL"])
Log.setup do |c|
  backend = ::Log::IOBackend.new

  c.bind "*", :warn, backend
  c.bind "tourmaline.*", :info, backend
  c.bind "mosquito.*", :info, backend
  c.bind "pubsubhubbub", :debug, backend
  c.bind "gemini", :debug, backend
  c.bind "turquoise.*", :debug, backend
end

require "granite"
require "granite/adapter/pg"
require "../ext/pubsubhubbub/subscriber"
require "./helpers"
require "./eloquent"
require "./pets"
require "./hooks"
require "./models/*"

# TODO: Write documentation for `Turquoise`
module Turquoise
  VERSION   = "0.3.0"
  USERAGENT = "Turquoise/#{VERSION}"
  Log       = ::Log.for("turquoise.app")
  Redis     = ::Redis::Client.new(URI.parse ENV["REDIS_URL"])
  Bot       = Tourmaline::Client.new(ENV["BOT_TOKEN"])

  PubSubHubbub.configure do |settings|
    settings.callback = File.join(ENV["HOST_URL"], ENV["YT_WEBHOOK_PATH"])
    settings.useragent = USERAGENT
  end

  Gemini.configure do |settings|
    settings.api_key = ENV["ELOQUENT_API_KEY"]
  end

  Mosquito.configure do |settings|
    settings.redis_url = ENV["REDIS_URL"]
  end
end

require "./jobs/**"
