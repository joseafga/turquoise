module Turquoise
  module Commands
    # Eloquent message when someone enter or left the group
    Bot.on :my_chat_member do |ctx|
      if my_chat_member = ctx.update.try &.my_chat_member
        status = my_chat_member.new_chat_member.status

        # new member in group
        if status == "member"
          theme = ["sedutora", "atrevida", "engraçada", "formal", "entusiasta da cultura japonesa"].sample

          if ctx.client.bot.id == my_chat_member.new_chat_member.user.id
            text = "Crie uma frase curta se apresentando para um grupo que você acabou de \
            chegar, seja #{theme}."
          else
            text = "Crie uma frase curta de boas-vindas para #{my_chat_member.new_chat_member.user.first_name}, que acabou de entrar no grupo, \
            seja #{theme}."
          end

          Helpers.persist_chat(my_chat_member.chat)
          ctx.send_chat_action(:typing)
          Jobs::SendChatCompletion.new(
            chat_id: my_chat_member.chat.id.to_i64,
            text: text,
            message_id: 0_i64
          ).enqueue
        end
      end
    end

    # Use eloquent to chat in private or group without commands
    Bot.on :text do |ctx|
      if message = ctx.message
        next unless message.text_entities("bot_command").to_a.empty?

        if text = message.text
          next if text.empty?

          Helpers.persist_chat(message.chat)
          ctx.send_chat_action(:typing)
          Jobs::SendChatCompletion.new(
            chat_id: message.chat.id.to_i64,
            text: text,
            message_id: message.message_id.to_i64
          ).enqueue
        end
      end
    end

    chat = Tourmaline::CommandHandler.new("chat") do |ctx|
      if message = ctx.message
        text = ctx.text.to_s
        next if text.empty?

        Helpers.persist_chat(message.chat)
        ctx.send_chat_action(:typing)
        Jobs::SendChatCompletion.new(
          chat_id: message.chat.id.to_i64,
          text: text,
          message_id: message.message_id.to_i64
        ).enqueue
      end
    end

    clear = Tourmaline::CommandHandler.new("limpar") do |ctx|
      if message = ctx.message
        Jobs::ResetChatCompletion.new(
          chat_id: message.chat.id.to_i64
        ).enqueue
      end
    end

    Bot.register chat, clear
  end
end
