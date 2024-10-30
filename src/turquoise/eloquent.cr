require "json"
require "./eloquent/types"

module Turquoise
  class Eloquent
    MODEL        = "gemini-1.5-flash-latest"
    ENDPOINT     = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent"
    MAX_MESSAGES =   6
    MAX_TOKENS   = 128
    HEADERS      = HTTP::Headers{"Content-Type" => "application/json"}

    getter chat : Models::Chat
    getter data : Chat::Request

    def initialize(chat_id)
      @chat = Models::Chat.find!(chat_id)
      @data = Chat::Request.new Chat::Content.new(system_role)

      @data.generation_config = Chat::Request::GenerationConfig.new(
        max_output_tokens: MAX_TOKENS
      )

      # More testing needed but default seems to be very strict
      @data.safety_settings = [
        Chat::SafetySetting.new(:HARM_CATEGORY_SEXUALLY_EXPLICIT, :BLOCK_NONE),
        Chat::SafetySetting.new(:HARM_CATEGORY_HATE_SPEECH, :BLOCK_NONE),
        Chat::SafetySetting.new(:HARM_CATEGORY_HARASSMENT, :BLOCK_NONE),
        Chat::SafetySetting.new(:HARM_CATEGORY_DANGEROUS_CONTENT, :BLOCK_NONE),
      ]

      # # setup function calling
      # @data.tools << Chat::Tool.new(
      #   name: "send_selfie_image",
      #   description: "Send a selfie. Call this when you need to send a photo of yourself."
      # )

      # @data.tools << Chat::Tool.new(
      #   name: "send_custom_image",
      #   description: "Send an image using AI. Call this when you need to create a custom image, for example when they ask for 'Create an image of a dog'.",
      #   parameters: {
      #     type:       "object",
      #     properties: {
      #       "prompt" => {
      #         type:        "string",
      #         description: "Description of what you want to create.",
      #       },
      #     },
      #     required: ["prompt"],
      #   })

      if messages = Redis.get("turquoise:eloquent:chat:#{@chat.id}")
        @data.contents = @data.contents.class.from_json(messages)
      else
        clear
      end
    end

    # Reset chat messages.
    def clear
      @data.contents.clear
      Redis.del "turquoise:eloquent:chat:#{chat.id}"
    end

    private def request(body : Chat::Request) : Chat::Result
      Log.debug { "eloquent -- #{chat.id}: #{body.to_pretty_json}" }
      response = HTTP::Client.post "#{ENDPOINT}?key=#{ENV["ELOQUENT_API_KEY"]}", body: body.to_json, headers: HEADERS

      case response.headers["Content-Type"][/[^;]+/]
      when "application/json"
        begin
          Chat::Result.from_json response.body
        rescue ex : JSON::SerializableError
          error = Error.from_json response.body, root: "error"
          raise %(eloquent -- #{chat.id}: Error #{error.code} - "#{error.message}")
        end
      else
        raise "eloquent -- Unknown Content-Type: #{response.headers["Content-Type"]}"
      end
    end

    # private def request(body : Prompt::Request)
    #   Log.debug { "eloquent -- #{chat.id}: #{body.to_pretty_json}" }
    #   response = HTTP::Client.post "#{ENDPOINT}#{MODEL[:text_to_image]}", body: body.to_json, headers: HEADERS

    #   case response.headers["Content-Type"]
    #   when "image/png"
    #     File.tempfile(suffix: ".png") do |file|
    #       file.print response.body
    #     end
    #   else
    #     raise "eloquent -- Unknown Content-Type: #{response.headers["Content-Type"]}"
    #   end
    # end

    def generate(text : String) : Chat::Content?
      @data << Chat::Content.new text, :user
      res = request(@data)

      candidate = res.candidates.first
      unless candidate.content
        Log.warn { %(eloquent -- #{chat.id}: Finished by `#{candidate.finish_reason}` -> "#{text}") }
        return
      end
      message = Chat::Content.new candidate.content.to_s.chomp, :model

      # Execute function calling
      # res.result[:tool_calls].try &.each do |tool_call|
      #   case tool_call.name
      #   when "send_selfie_image"
      #     send_selfie_image tool_call, pointerof(message)
      #   when "send_custom_image"
      #     send_custom_image tool_call, pointerof(message)
      #   else
      #     # TODO: Undefined tool call
      #     message.content = "TODO: #{tool_call}"
      #   end
      # end

      @data << message
      Redis.set "turquoise:eloquent:chat:#{chat.id}", @data.contents.to_json
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

    def send_selfie_image(tool_call : Chat::Tool::Call, message : Chat::Content*)
      file = random_selfie
      description = File.basename(file.path, ".jpg")

      # Store some image information to IA generate response based on this
      @data << Chat::Content.new %({"image_description": "#{description}."}), :tool
      res = request(@data)
      message.value.content = res.result[:response].to_s
      message.value.photo = file
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      image = Dir.glob(File.join(dir, "/*.jpg")).sample

      File.open(image, "rb")
    end

    # def send_custom_image(tool_call : Chat::Tool::Call, message : Chat::Content*)
    #   data << Chat::Content.new %({"success": "#{tool_call.arguments["prompt"]}"}), :tool
    #   req = Prompt::Request.new(tool_call.arguments["prompt"], 20)
    #   tmp = request(req)

    #   message.value.photo = File.open(tmp.path, "rb")
    #   message.value.content = tool_call.arguments["prompt"]
    #   tmp.delete
    # end
  end
end
