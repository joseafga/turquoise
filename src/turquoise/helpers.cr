module Turquoise
  module Helpers
    extend Tourmaline::Helpers
    extend self

    # Save or update Users to database
    def persist_user(users : Array)
      models = [] of Models::User

      users.uniq(&.id).each do |user|
        models << Models::User.new(
          id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          username: user.username,
          language_code: user.language_code,
          is_bot: user.is_bot?
        )
      end

      Models::User.import(models, update_on_duplicate: true,
        columns: %w(first_name last_name username language_code))
    end

    def persist_user(user : Tourmaline::User)
      persist_user [user]
    end

    # Save or update Chats to database
    def persist_chat(chats : Array)
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
          is_forum: chat.is_forum?
        )
      end

      Models::Chat.import(models, update_on_duplicate: true,
        columns: %w(type title username first_name last_name description is_forum))
    end

    def persist_chat(chat : Tourmaline::Chat)
      persist_chat [chat]
    end
  end
end
