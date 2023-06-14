module Turquoise
  subscribe = Tourmaline::CommandHandler.new("inscrever") do |ctx|
    # sub.subscribe
    puts ctx.update.message.try &.chat.id
    ctx.reply("Inscrito com sucesso!")
  end

  Bot.register subscribe
end
