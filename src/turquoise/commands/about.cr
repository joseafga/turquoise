module Turquoise
  module Commands
    about = Tourmaline::CommandHandler.new(["about", "sobre"]) do |ctx|
      text = "Olá, eu sou a *Turquesa*, um bot do Telegram super antenada nas últimas \
            novidades do YouTube! Além disso, adoro me divertir com outras atividades! \
            🥰\n\n\
            Conheça também meu [repositório no GitHub](https://github.com/joseafga/turquoise)."

      ctx.reply(text, disable_web_page_preview: true)
    end

    Bot.register about
  end
end
