module Turquoise
  module Commands
    # TODO: internationalization
    # Eloquent message when someone enter in the group.
    Bot.on :new_chat_members do |ctx|
      if message = ctx.message
        theme = ["sedutora", "atrevida", "engraçada", "formal", "entusiasta da cultura japonesa"].sample
        members = message.new_chat_members.join(", ") do |user|
          user.first_name
        end

        # Turquoise joined in a group
        yourself = message.new_chat_members.any? do |member|
          member.id == ctx.client.bot.id
        end

        if yourself
          text = "Crie uma frase curta se apresentando para um grupo que você acabou de chegar, seja #{theme}."
        else # New member in the group
          text = "Crie uma frase curta de boas-vindas para #{members}, que acabou de entrar no grupo, seja #{theme}."
        end

        Helpers.persist_chat(message.chat)
        ctx.send_chat_action(:typing)
        Jobs::SendChatCompletion.new(
          chat_id: message.chat.id.to_i64,
          message_id: 0_i64,
          text: text,
        ).enqueue
      end
    end

    # Use eloquent to chat in private or group without commands
    Bot.on :text do |ctx|
      if message = ctx.message
        next unless message.text_entities("bot_command").to_a.empty?

        if text = message.text
          next if text.empty?

          Helpers.persist_chat(message.chat)
          Helpers.persist_user(message.users)
          ctx.send_chat_action(:typing)
          Jobs::SendChatCompletion.new(
            chat_id: message.chat.id.to_i64,
            message_id: message.message_id.to_i64,
            text: text,
          ).enqueue
        end
      end
    end

    chat = Tourmaline::CommandHandler.new("chat") do |ctx|
      if message = ctx.message
        text = ctx.text.to_s
        next if text.empty?

        Helpers.persist_chat(message.chat)
        Helpers.persist_user(message.users)
        ctx.send_chat_action(:typing)
        Jobs::SendChatCompletion.new(
          chat_id: message.chat.id.to_i64,
          message_id: message.message_id.to_i64,
          text: text,
        ).enqueue
      end
    end

    clear = Tourmaline::CommandHandler.new(["clear", "limpar"]) do |ctx|
      if message = ctx.message
        Jobs::ResetChatCompletion.new(
          chat_id: message.chat.id.to_i64
        ).enqueue
      end
    end

    Bot.register chat, clear
  end
end
