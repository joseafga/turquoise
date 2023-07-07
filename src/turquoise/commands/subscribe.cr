module Turquoise
  subscribe = Tourmaline::CommandHandler.new("inscrever") do |ctx|
    if message = ctx.message
      user = Tourmaline::User.cast(message.from)
      chat = Tourmaline::Chat.cast(message.chat)
      topic = "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ctx.text.to_s}"

      Helpers.persist_user(user)
      Helpers.persist_chat(chat)

      # TODO: change to job
      if Models::Listener.exists? chat_id: chat.id, subscription_topic: topic
        raise "O grupo já está inscrito neste canal."
      end

      if subscription = Models::Subscription.find(topic)
        subscription.subscribe unless subscription.active?
      else
        Models::Subscription.create! topic: topic
      end

      Models::Listener.create! user_id: user.id, chat_id: chat.id, subscription_topic: topic
      ctx.reply("Inscrito com sucesso. 🫡")
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
    message = "Erro ao inscrever-se: #{ex.message || ex.cause.try &.message}"
    ctx.reply(Helpers.escape_md message)
  end

  Bot.register subscribe
end
