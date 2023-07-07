module Turquoise
  module Commands
    start = Tourmaline::CommandHandler.new(["help", "start"]) do |ctx|
      markup = Tourmaline::Client.build_reply_keyboard_markup(columns: 2) do |kb|
        kb.button "/sobre"
        kb.button "/gato 😺"
        kb.button "/cachorro 🐶"
        kb.button "/jogo"
      end
      ctx.reply("Experimente os comandos: /gato, /cachorro ou /sobre", reply_markup: markup)
    end

    Bot.register start
  end
end
