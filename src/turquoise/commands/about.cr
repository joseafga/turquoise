Turquoise::Bot.command do |bot|
  cmd = Tourmaline::CommandHandler.new("sobre") do |ctx|
    # puts ctx.inspect
    puts Turquoise::Subscriber.inspect
  end

  bot.register cmd
end
