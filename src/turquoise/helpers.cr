module Turquoise
  module Helpers
    extend self

    def escape_md(text, version = 1)
      case version
      when 0, 1
        escapes = ['_', '*', '`']
      when 2
        escapes = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!']
      else
        raise "Invalid version #{version} for `escape_md`"
      end

      text.to_s.gsub do |char|
        escapes.includes?(char) ? "\\#{char}" : char
      end
    end

    # Configure webook only if is needed
    def config_webhook
      url = File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])

      unless Redis.get("turquoise:telegram:webhook") == url
        Log.info { "Configuring Webhook ..." }
        Bot.delete_webhook
        Bot.set_webhook url
        Redis.set "turquoise:telegram:webhook", url
      end
    end

    # Basically Tourmaline::Server without a new HTTP::Server
    def handle_webhook(context)
      Fiber.current.telegram_bot_server_http_context = context

      return unless context.request.method == "POST"
      return unless context.request.path == ENV["BOT_WEBHOOK_PATH"]

      if body = context.request.body.try &.gets_to_end
        Log.debug { "receiving ◄◄ #{JSON.parse(body).to_pretty_json}" }

        update = Tourmaline::Update.from_json(body)
        Bot.dispatcher.process(update)
      end
    rescue ex
      Log.error(exception: ex) { "Server error" }
    ensure
      Fiber.current.telegram_bot_server_http_context = nil
    end

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
