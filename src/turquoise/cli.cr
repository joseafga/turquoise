require "option_parser"

module Turquoise
  module CLI
    welcome_chat = ENV["BOT_OWNER"]
    welcome_message = "Ready!"

    OptionParser.parse do |parser|
      parser.banner = "Telegram bot for YouTube notifications and fun."

      parser.on "--delete-webhook", "Delete Telegram webhook" do
        Log.info { "Deleting Telegram webhook." }
        Bot.delete_webhook
      end
      parser.on "-c CHAT", "--chat=CHAT", "Welcome message chat id" { |chat| welcome_chat = chat }
      parser.on "-m MESSAGE", "--message=MESSAGE", "Welcome message text" { |message| welcome_message = message }
      parser.on "-h", "--help", "Show help" do
        puts parser
        exit
      end
      parser.on "-v", "--version", "Show version" do
        puts "version #{VERSION}"
        exit
      end
    end

    spawn do
      Bot.send_message welcome_chat, text: welcome_message
    end
  end
end
