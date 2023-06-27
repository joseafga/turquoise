module Turquoise
  subscribe = Tourmaline::CommandHandler.new("inscrever") do |ctx|
    if message = ctx.message
      user = Tourmaline::User.cast(message.from)
      chat = Tourmaline::Chat.cast(message.chat)
      text = ctx.text.to_s
      sub = Models::Subscription.new user_id: user.id, chat_id: chat.id, topic: text, is_active: true

      if sub.exists?
        raise "O chat já está recebendo notificações deste tópico. \
              Em caso de erro, tente se /desinscrever e /inscrever novamente."
      else
        Helpers.persist_user(user)
        Helpers.persist_chat(chat)
        sub.save!

        if sub.active?
          ctx.reply("Inscrito com sucesso.")
        else
          # TODO: Need validation and webhook
          # PubSubHubbub::Subscriber.new(
          #   "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{sub.topic}",
          #   ENV["HUB_CALLBACK"],
          #   ENV["HUB_SECRET"]?
          # )

          ctx.reply("Pedido de inscrição com sucesso, aguarde a confirmação do servidor.")
        end
      end
    end
  rescue ex : Granite::RecordNotSaved
    message = String.build do |msg|
      msg << "Ocorreram os seguintes erros:"

      ex.model.errors.each do |error|
        msg << "\n- #{error.message}"
      end
    end

    ctx.reply(Helpers.escape_md message)
  rescue ex
    ctx.reply(Helpers.escape_md ex.message)
  end

  Bot.register subscribe
end
