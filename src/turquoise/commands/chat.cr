require "json"
require "http/client"

module Turquoise
  module Commands
    chat = Tourmaline::CommandHandler.new("chat") do |ctx|
      text = ctx.text.to_s
      next if text.empty?

      Jobs::SendEloquentMessage.new(
        message_id: ctx.message!.message_id.to_i64,
        chat_id: ctx.message!.chat.id.to_i64,
        text: text
      ).enqueue
    end

    Bot.register chat
  end
end
