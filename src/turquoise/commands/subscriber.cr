module Turquoise
  module Commands
    subscribe = Tourmaline::CommandHandler.new("inscrever") do |ctx|
      if message = ctx.message
        user = Tourmaline::User.cast(message.from)
        chat = Tourmaline::Chat.cast(message.chat)
        topic = "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ctx.text}"

        Helpers.persist_user(user)
        Helpers.persist_chat(chat)
        Jobs::Subscribe.new(message_id: message.message_id.to_i64, user_id: user.id.to_i64, chat_id: chat.id.to_i64, topic: topic).enqueue
      end
    end

    unsubscribe = Tourmaline::CommandHandler.new("desinscrever") do |ctx|
      if message = ctx.message
        chat = Tourmaline::Chat.cast(message.chat)
        topic = "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ctx.text}"

        Jobs::Unsubscribe.new(message_id: message.message_id.to_i64, chat_id: chat.id.to_i64, topic: topic).enqueue
      end
    end

    Bot.register subscribe, unsubscribe
  end
end
