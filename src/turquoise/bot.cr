require "tourmaline"

module Turquoise
  class Bot < Tourmaline::Client
    @@commands = [] of Turquoise::Bot ->

    def self.command(&block : Turquoise::Bot ->)
      @@commands << block
    end

    def self.register_commands(client)
      @@commands.each &.call(client)
    end

    def register_commands
      self.class.register_commands(self)
    end
  end
end

require "./commands/*"
