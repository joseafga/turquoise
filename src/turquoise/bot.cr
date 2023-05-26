require "tourmaline"

module Turquoise
  class Bot < Tourmaline::Client
    @@commands = [] of Turquoise::Bot ->

    def self.command(&block : Turquoise::Bot ->)
      @@commands << block
    end

    def self.register_commands(client)
      @@commands.each &.call(client)
    end

    def register_commands
      self.class.register_commands(self)
    end
  end

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

require "./commands/*"
