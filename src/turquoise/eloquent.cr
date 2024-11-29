module Turquoise
  class Eloquent
    MAX_MESSAGES = 10
    MODEL_CONFIG = {
      model_name:        ENV["ELOQUENT_MODEL"],
      generation_config: Gemini::GenerationConfig.new(
        max_output_tokens: 128
      ),
      # More testing needed but default seems to be very strict
      safety_settings: [
        Gemini::SafetySetting.new(:HARM_CATEGORY_SEXUALLY_EXPLICIT, :BLOCK_NONE),
        Gemini::SafetySetting.new(:HARM_CATEGORY_HATE_SPEECH, :BLOCK_NONE),
        Gemini::SafetySetting.new(:HARM_CATEGORY_HARASSMENT, :BLOCK_NONE),
        Gemini::SafetySetting.new(:HARM_CATEGORY_DANGEROUS_CONTENT, :BLOCK_NONE),
      ],
      # setup function calling
      tools: [Gemini::Tool.new([
        Gemini::FunctionDeclaration.new(
          "send_selfie_image",
          description: "Send a selfie. Call this when you need to send a photo of yourself."
        ),
        Gemini::FunctionDeclaration.new(
          "send_custom_image",
          description: "Send an image using AI. Call this when you need to create a custom image, for example when they ask for 'Create an image of a dog'.",
          parameters: Gemini::Schema.new(
            type: :OBJECT,
            properties: {
              "prompt" => Gemini::Schema.new(
                type: :STRING,
                description: "Description of what you want to create.",
              ),
            },
            required: ["prompt"],
          )
        ),
      ])],
    }

    getter chat : Models::Chat
    getter data = Deque(Gemini::Content).new(MAX_MESSAGES)
    # Send media using telegram API
    getter media = [] of Tourmaline::InputMediaPhoto

    def initialize(chat_id)
      @chat = Models::Chat.find!(chat_id)
      @model = Gemini::GenerativeModel.new(**MODEL_CONFIG, system_instruction: Gemini::Content.new(system_role))

      load
    end

    # Keep maximum size
    def push(message : Gemini::Content)
      data.shift if data.size >= MAX_MESSAGES
      data.push message

      message
    end

    def load
      if messages = Redis.get("turquoise:eloquent:chat:#{chat.id}")
        @data = data.class.from_json(messages)
      else
        clear
      end
    end

    def save!
      Redis.set "turquoise:eloquent:chat:#{chat.id}", data.to_json
    end

    # Reset chat messages.
    def clear
      data.clear
      Redis.del "turquoise:eloquent:chat:#{chat.id}"
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

    def generate(text : String)
      push Gemini::Content.new(text, :user)
      response = @model.generate_content(data)

      if (candidate = response.candidates.first) && candidate.content.nil?
        Log.warn { %(eloquent -- #{chat.id}: Finished by `#{candidate.finish_reason}` -> "#{text}") }
        return
      end

      # message = Gemini::Content.new response.text, :model
      function_calling_handler pointerof(response)

      # push message
      push Gemini::Content.new(response.text, :model)
      response
    end

    def function_calling_handler(response : Gemini::GenerateContentResponse*)
      function_parts = [] of Gemini::Part

      # Execute function calling
      response.value.parts.each &.function_call? do |func_call|
        return unless func_call.is_a?(Gemini::FunctionCall)
        case func_call.name
        when "send_selfie_image"
          function_parts << send_selfie_image(func_call)
        when "send_custom_image"
          function_parts << send_custom_image(func_call)
        else
          # TODO: Undefined tool call
          function_parts << Gemini::Part.new("TODO: #{func_call}")
        end
      end

      # Handle function calling `Parts` result
      if function_parts.present?
        push Gemini::Content.new(response.value.parts, :model)
        push Gemini::Content.new(function_parts, :function)

        res = @model.generate_content(data)
        # Message will receive text part of function calling response
        response.value = res
      end
    end

    def send_selfie_image(func_call : Gemini::FunctionCall) : Gemini::Part
      selfie_path = random_selfie
      description = File.basename(selfie_path, ".jpg")
      media << Tourmaline::InputMediaPhoto.new(media: selfie_path)

      Gemini::Part.new(
        Gemini::FunctionResponse.new(
          func_call.name,
          JSON.parse(%({ "description": "#{description}."}))
        )
      )
    end

    def random_selfie : String
      dir = File.expand_path("../../img/pictures/", __DIR__)
      Dir.glob(File.join(dir, "/*.jpg")).sample
    end

    def send_custom_image(func_call : Gemini::FunctionCall) : Gemini::Part
      # TODO: New method for image generation
      # req = Prompt::Request.new(tool_call.args["prompt"], 20)
      # tmp = request(req)
      # media << Tourmaline::InputMediaPhoto.new(
      #   media: tmp.path,
      #   caption: %("#{func_call.args.try &.["prompt"]}")
      # )

      Gemini::Part.new(
        Gemini::FunctionResponse.new(
          func_call.name,
          JSON.parse(%({ "description": "#{func_call.args.try &.["prompt"]}."}))
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
