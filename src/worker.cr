require "./turquoise/app"

module Turquoise
  Signal::INT.trap do
    Mosquito::Runner.stop
  end

  Mosquito::Runner.start
end
