API_URL_CAT = "https://api.thecatapi.com/v1/images/search"
API_URL_DOG = "https://api.thedogapi.com/v1/images/search"

Turquoise::Bot.command do |bot|
  cmd = Tourmaline::CommandHandler.new(["gato", "cachorro"]) do |ctx|
    response = HTTP::Client.get ctx.command!.starts_with?("gato") ? API_URL_CAT : API_URL_DOG
    data = Array(Hash(String, String | UInt16)).from_json(response.body)
    image = data.first["url"].to_s

    ctx.send_chat_action(:upload_photo)
    if ::File.extname(image) == ".gif"
      ctx.respond_with_animation(image)
    else # .jpg, .png
      ctx.respond_with_photo(image)
    end
  rescue
    # If rate limit as reached or API changed
    ctx.reply("😿 Xiiiiii! Deu ruim, tente novamente daqui a pouco. 🐶")
  end

  bot.register cmd
end
