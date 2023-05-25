Turquoise::Bot.command do |bot|
  cmd = Tourmaline::CommandHandler.new(["help", "start"]) do |ctx|
    markup = Tourmaline::Client.build_reply_keyboard_markup do |kb|
      kb.button "/gato"
      kb.button "/cachorro"
    end
    ctx.reply("😺 Use commands: /gato, /cachorro and /sobre", reply_markup: markup)
  end

  bot.register cmd
end
