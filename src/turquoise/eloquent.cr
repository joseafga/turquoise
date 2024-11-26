require "json"
require "mime/media_type"
require "./eloquent/types"

module Turquoise
  class Eloquent
    MODEL        = "gemini-1.5-flash"
    ENDPOINT     = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent"
    MAX_MESSAGES =  10
    MAX_TOKENS   = 128
    HEADERS      = HTTP::Headers{"Content-Type" => "application/json"}
    # setup function calling
    TOOL = Chat::Tool.new [
      Chat::FunctionDeclaration.new(
        "send_selfie_image",
        description: "Send a selfie. Call this when you need to send a photo of yourself."
      ),
      Chat::FunctionDeclaration.new(
        "send_custom_image",
        description: "Send an image using AI. Call this when you need to create a custom image, for example when they ask for 'Create an image of a dog'.",
        parameters: Chat::Schema.new(
          type: :OBJECT,
          properties: {
            "prompt" => Chat::Schema.new(
              type: :STRING,
              description: "Description of what you want to create.",
            ),
          },
          required: ["prompt"],
        )
      ),
    ]

    getter chat : Models::Chat
    getter data : Chat::Request
    # Send media using telegram API
    getter media = [] of Tourmaline::InputMediaPhoto

    def initialize(chat_id)
      @chat = Models::Chat.find!(chat_id)
      @data = Chat::Request.new Chat::Content.new(system_role)
      @data.tools = [TOOL]

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

      load
    end

    def load
      if messages = Redis.get("turquoise:eloquent:chat:#{chat.id}")
        @data.contents = @data.contents.class.from_json(messages)
      else
        clear
      end
    end

    def save!
      Redis.set "turquoise:eloquent:chat:#{chat.id}", @data.contents.to_json
    end

    # Reset chat messages.
    def clear
      @data.contents.clear
      Redis.del "turquoise:eloquent:chat:#{chat.id}"
    end

    private def request(body : Chat::Request) : Chat::Result
      Log.debug { "eloquent -- #{chat.id}: #{body.to_pretty_json}" }
      response = HTTP::Client.post "#{ENDPOINT}?key=#{ENV["ELOQUENT_API_KEY"]}", body: body.to_json, headers: HEADERS
      content_type = MIME::MediaType.parse(response.headers["Content-Type"])

      case content_type.media_type
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

      if candidate.content.nil?
        Log.warn { %(eloquent -- #{chat.id}: Finished by `#{candidate.finish_reason}` -> "#{text}") }
        return
      end

      message = Chat::Content.new candidate.content!.parts, :model
      function_calling_handler pointerof(message)

      @data << message
      message
    end

    def function_calling_handler(message : Chat::Content*)
      function_parts = [] of Chat::Part

      # Execute function calling
      message.value.parts.each &.function_call? do |func_call|
        return unless func_call.is_a?(Chat::FunctionCall)
        case func_call.name
        when "send_selfie_image"
          function_parts << send_selfie_image(func_call)
        when "send_custom_image"
          function_parts << send_custom_image(func_call)
        else
          # TODO: Undefined tool call
          function_parts << Chat::Part.new("TODO: #{func_call}")
        end
      end

      # Handle function calling `Parts` result
      if function_parts.present?
        @data << message.value
        @data << Chat::Content.new function_parts, :function

        res = request(@data)
        # Message will receive text part of function calling response
        message.value.parts = [Chat::Part.new(res.candidates.first.content.to_s)]
      end
    end

    def send_selfie_image(func_call : Chat::FunctionCall) : Chat::Part
      selfie_path = random_selfie
      description = File.basename(selfie_path, ".jpg")
      media << Tourmaline::InputMediaPhoto.new(media: selfie_path)

      Chat::Part.new(
        Chat::FunctionResponse.new(
          func_call.name,
          JSON.parse(%({"image": { "description": "#{description}."}}))
        )
      )
    end

    def random_selfie : String
      dir = File.expand_path("../../img/pictures/", __DIR__)
      Dir.glob(File.join(dir, "/*.jpg")).sample
    end

    def send_custom_image(func_call : Chat::FunctionCall) : Chat::Part
      # TODO: New method for image generation
      # req = Prompt::Request.new(tool_call.args["prompt"], 20)
      # tmp = request(req)
      # media << Tourmaline::InputMediaPhoto.new(
      #   media: tmp.path,
      #   caption: %("#{func_call.args.try &.["prompt"]}")
      # )

      Chat::Part.new(
        Chat::FunctionResponse.new(
          func_call.name,
          JSON.parse(%({"image": { "description": "#{func_call.args.try &.["prompt"]}."}}))
          # JSON.parse(%({"status": "success"}))
        )
      )
    end

    # TODO: internationalization
    def system_role
      if chat.type == "private"
        "#{ENV["ELOQUENT_ROLE"]} You are in a private chat with #{chat.first_name}."
      else
        "#{ENV["ELOQUENT_ROLE"]} You are in a group chatting with friends."
      end
    end

    # Check if `#media` has captions
    def media_captions? : Bool
      !!media.bsearch(&.caption)
    end
  end
end
