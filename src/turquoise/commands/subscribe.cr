module Turquoise
  subscribe = Tourmaline::CommandHandler.new("inscrever") do |ctx|
    if message = ctx.message
      user = Tourmaline::User.cast(message.from)
      chat = Tourmaline::Chat.cast(message.chat)
      topic = "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ctx.text.to_s}"

      Helpers.persist_user(user)
      Helpers.persist_chat(chat)

      # TODO: change to job
      subscription = Models::Subscription.new user_id: user.id, chat_id: chat.id, topic: topic, is_active: true

      if subscription.exists?
        raise "O chat já está recebendo notificações deste tópico. \
              Em caso de erro, tente se /desinscrever e /inscrever novamente."
      else
        if subscription.active?
          subscription.save!
          ctx.reply("Inscrito com sucesso. 🫡")
        else
          subscription.save!
          subscription.subscriber.subscribe
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
    message = "`#{ex.class}`: #{ex.message || ex.cause.try &.message}"
    ctx.reply(Helpers.escape_md message)
  end

  Bot.register subscribe
end
