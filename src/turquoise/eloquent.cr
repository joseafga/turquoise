require "json"
require "./eloquent/api"

module Turquoise
  class Eloquent
    MODEL = {
      text_generation: "@hf/nousresearch/hermes-2-pro-mistral-7b",
      text_to_image:   "@cf/stabilityai/stable-diffusion-xl-base-1.0",
    }
    ENDPOINT     = "https://api.cloudflare.com/client/v4/accounts/#{ENV["ELOQUENT_ACCOUNT_ID"]}/ai/run/"
    MAX_MESSAGES = 6
    MAX_TOKENS   = nil # Defaults is 256
    HEADERS      = HTTP::Headers{"Authorization" => "Bearer #{ENV["ELOQUENT_API_KEY"]}", "Content-Type" => "application/json"}

    getter chat : Models::Chat
    property data : Chat::Request

    def initialize(chat_id)
      @chat = Models::Chat.find!(chat_id)
      @data = Chat::Request.new

      # setup function calling
      @data.tools << Chat::Tool.new(
        name: "send_selfie_image",
        description: "Send a selfie. Call this when you need to send a photo of yourself."
      )

      @data.tools << Chat::Tool.new(
        name: "send_custom_image",
        description: "Send an image using AI. Call this when you need to create a custom image, for example when they ask for 'Create an image of a dog'.",
        parameters: {
          type:       "object",
          properties: {
            "prompt" => {
              type:        "string",
              description: "Description of what you want to create.",
            },
          },
          required: ["prompt"],
        })

      if messages = Redis.get("turquoise:eloquent:chat:#{@chat.id}")
        @data.messages = data.messages.class.from_json(messages)
      else
        clear
      end
    end

    # Reset chat messages.
    def clear
      data.messages.clear
      Redis.del "turquoise:eloquent:chat:#{chat.id}"
    end

    private def request(body : Chat::Request)
      # Insert system message to IA acts like
      system_message = Chat::Completion::Message.new :system, system_role
      body.messages = body.messages.dup.insert 0, system_message

      Log.debug { "eloquent -- #{chat.id}: #{body.to_pretty_json}" }
      response = HTTP::Client.post "#{ENDPOINT}#{MODEL[:text_generation]}", body: body.to_json, headers: HEADERS

      case response.headers["Content-Type"]
      when "application/json"
        Chat::Result.from_json response.body
      else
        raise "eloquent -- Unknown Content-Type: #{response.headers["Content-Type"]}"
      end
    end

    private def request(body : Prompt::Request)
      Log.debug { "eloquent -- #{chat.id}: #{body.to_pretty_json}" }
      response = HTTP::Client.post "#{ENDPOINT}#{MODEL[:text_to_image]}", body: body.to_json, headers: HEADERS

      case response.headers["Content-Type"]
      when "image/png"
        File.tempfile(suffix: ".png") do |file|
          file.print response.body
        end
      else
        raise "eloquent -- Unknown Content-Type: #{response.headers["Content-Type"]}"
      end
    end

    def completion(text : String) : Chat::Completion::Message
      data << Chat::Completion::Message.new :user, text
      res = request(data)

      # When some error happen, skip store data but show message to user
      unless res.errors.empty?
        return Chat::Completion::Message.new :assistant, res.errors.join('\n')
      end

      message = Chat::Completion::Message.new :assistant, res.result[:response].to_s

      # Execute function calling
      res.result[:tool_calls].try &.each do |tool_call|
        case tool_call.name
        when "send_selfie_image"
          send_selfie_image tool_call, pointerof(message)
        when "send_custom_image"
          send_custom_image tool_call, pointerof(message)
        else
          # TODO: Undefined tool call
          message.content = "TODO: #{tool_call}"
        end
      end

      data << message
      Redis.set "turquoise:eloquent:chat:#{chat.id}", data.messages.to_json
      message
    end

    # TODO: internationalization
    def system_role
      if chat.type == "private"
        "#{ENV["ELOQUENT_ROLE"]} You are in a private chat with #{chat.first_name}."
      else
        "#{ENV["ELOQUENT_ROLE"]} You are in a group chatting with friends."
      end
    end

    def send_selfie_image(tool_call : Chat::Tool::Call, message : Chat::Completion::Message*)
      file = random_selfie
      description = File.basename(file.path, ".jpg")

      # Store some image information to IA generate response based on this
      data << Chat::Completion::Message.new :tool, %({"image_description": "#{description}."})
      res = request(data)
      message.value.content = res.result[:response].to_s
      message.value.photo = file
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      image = Dir.glob(File.join(dir, "/*.jpg")).sample

      File.open(image, "rb")
    end

    def send_custom_image(tool_call : Chat::Tool::Call, message : Chat::Completion::Message*)
      data << Chat::Completion::Message.new :tool, %({"success": "#{tool_call.arguments["prompt"]}"})
      req = Prompt::Request.new(tool_call.arguments["prompt"], 20)
      tmp = request(req)

      message.value.photo = File.open(tmp.path, "rb")
      message.value.content = tool_call.arguments["prompt"]
      tmp.delete
    end
  end
end
