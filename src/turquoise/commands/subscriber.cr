Turquoise::Bot.command do |bot|
  cmd = Tourmaline::CommandHandler.new("inscrever") do |ctx|
    # sub.subscribe
    puts ctx.update.message.try &.chat.id
    ctx.reply("Inscrito com sucesso!")
  end

  bot.register cmd
end
