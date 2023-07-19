module Turquoise
  module Commands
    cat = Tourmaline::CommandHandler.new("gato") do |ctx|
      ctx.send_chat_action(:upload_photo)
      Jobs::SendCatPicture.new(chat_id: ctx.message!.chat.id.to_i64).enqueue
    end

    dog = Tourmaline::CommandHandler.new("cachorro") do |ctx|
      ctx.send_chat_action(:upload_photo)
      Jobs::SendDogPicture.new(chat_id: ctx.message!.chat.id.to_i64).enqueue
    end

    Bot.register cat, dog
  end
end
