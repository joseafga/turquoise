module Turquoise
  module Commands
    extend self
    APPROACH = ["sedutora", "atrevida", "engraçada", "formal", "entusiasta da cultura japonesa"]

    def message_to_eloquence(text, message)
      return if text.empty?

      if message.chat.type == "private"
        message_id = 0_i64
      else
        message_id = message.message_id.to_i64
        text = "#{(message.from.try &.first_name).to_s} say: #{text}"
      end

      Helpers.persist_chat(message.chat)
      Helpers.persist_user(message.users)
      Bot.send_chat_action(chat_id: message.chat.id, action: "typing")
      Jobs::SendChatEloquence.new(chat_id: message.chat.id.to_i64, message_id: message_id, text: text).enqueue
    end

    # TODO: internationalization
    # Eloquent message when someone enter in the group.
    Bot.on :new_chat_members do |ctx|
      if message = ctx.message
        members = message.new_chat_members.join(", ") do |user|
          user.first_name
        end

        # Turquoise joined in a group
        yourself = message.new_chat_members.any? do |member|
          member.id == ctx.client.bot.id
        end

        if yourself
          text = "Crie uma frase curta se apresentando para um grupo que você acabou de chegar, seja #{APPROACH.sample}."
        else # New member in the group
          text = "Crie uma frase curta de boas-vindas para #{members}, que acabou de entrar no grupo, seja #{APPROACH.sample}."
        end

        Helpers.persist_chat(message.chat)
        ctx.send_chat_action(:typing)
        Jobs::SendChatEloquence.new(chat_id: message.chat.id.to_i64, message_id: 0_i64, text: text).enqueue
      end
    end

    # Use eloquent to chat in private or group when reply
    Bot.on :text do |ctx|
      if message = ctx.message
        next if message.text_entities("bot_command").to_a.present?
        message_to_eloquence(message.text.to_s, message)
      end
    end

    # Use eloquent to chat in private or group with `/chat` command
    chat = Tourmaline::CommandHandler.new("chat") do |ctx|
      if message = ctx.message
        message_to_eloquence(ctx.text.to_s, message)
      end
    end

    clear = Tourmaline::CommandHandler.new(["clear", "limpar"]) do |ctx|
      if message = ctx.message
        ctx.send_chat_action(:typing)
        Jobs::ResetChatEloquence.new(chat_id: message.chat.id.to_i64).enqueue
      end
    end

    Bot.register chat, clear
  end
end
