require "./turquoise/app"
require "./turquoise/cli"
require "./turquoise/commands/**"

module Turquoise
  # Configure telegram webhook
  spawn do
    Bot.set_webhook File.join(ENV["HOST_URL"], ENV["BOT_WEBHOOK_PATH"])
    CLI.send_welcome
  end

  CLI.run
end
