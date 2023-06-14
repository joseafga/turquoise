module Turquoise
  API_URL_CAT = "https://api.thecatapi.com/v1/images/search"
  API_URL_DOG = "https://api.thedogapi.com/v1/images/search"

  cat = Tourmaline::CommandHandler.new("gato") do |ctx|
    ctx.send_chat_action(:upload_photo)
    Jobs::SendPetPicture.new(api_url: API_URL_CAT, chat_id: ctx.message!.chat.id.to_i64).enqueue
  end

  dog = Tourmaline::CommandHandler.new("cachorro") do |ctx|
    ctx.send_chat_action(:upload_photo)
    Jobs::SendPetPicture.new(api_url: API_URL_DOG, chat_id: ctx.message!.chat.id.to_i64).enqueue
  end

  Bot.register cat, dog
end
