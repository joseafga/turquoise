require "./turquoise/app"
require "./turquoise/cli"
require "./turquoise/commands/**"

module Turquoise
  # Configure telegram webhook
  spawn do
    CLI.send_welcome
  end

  CLI.run
end
