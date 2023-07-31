module Turquoise
  module Commands
    cat = Tourmaline::CommandHandler.new(["cat", "gato"]) do |ctx|
      ctx.send_chat_action(:upload_photo)
      Jobs::SendPetImage.new(pet: "cat", chat_id: ctx.message!.chat.id.to_i64).enqueue
    end

    dog = Tourmaline::CommandHandler.new(["dog", "cachorro"]) do |ctx|
      ctx.send_chat_action(:upload_photo)
      Jobs::SendPetImage.new(pet: "dog", chat_id: ctx.message!.chat.id.to_i64).enqueue
    end

    Bot.register cat, dog
  end
end
