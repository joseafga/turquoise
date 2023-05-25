Turquoise::Bot.command do |bot|
  cmd = Tourmaline::CommandHandler.new("sobre") do |ctx|
    text = "Olá, eu sou a *Turquesa*, um bot do Telegram super antenada nas últimas \
      novidades do YouTube! Além disso, adoro me divertir com outras atividades também! \
      🥰\n\n\
      Conheça também meu [repositório no GitHub](https://github.com/joseafga/turquoise)."
    
    ctx.reply(text, disable_web_page_preview: true)
  end

  bot.register cmd
end
