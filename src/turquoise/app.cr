require "mosquito"
require "tourmaline"
require "dotenv"
require "pg"

Dotenv.load? ".env"
Granite::Connections << Granite::Adapter::Pg.new(name: "pg", url: ENV["DATABASE_URL"])

require "granite"
require "granite/adapter/pg"
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

  # Save or update User to database
  def self.persist_user(users : Array)
    models = [] of Models::User

    users.uniq(&.id).each do |user|
      models << Models::User.new(
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        username: user.username,
        language_code: user.language_code,
        is_bot: user.is_bot?,
      )
    end

    Models::User.import(models, update_on_duplicate: true,
      columns: %w(first_name last_name username language_code))
  end

  # Save or update Chat to database
  def self.persist_chat(chats : Array)
    models = [] of Models::Chat

    chats.uniq(&.id).each do |chat|
      models << Models::Chat.new(
        id: chat.id,
        type: chat.type,
        title: chat.title,
        username: chat.username,
        first_name: chat.first_name,
        last_name: chat.last_name,
        description: chat.description,
        is_forum: chat.is_forum?,
      )
    end

    Models::Chat.import(models, update_on_duplicate: true,
      columns: %w(type title username first_name last_name description is_forum))
  end
end

require "./jobs/**"
