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
        Gemini::SafetySetting.new(:HarmCategorySexuallyExplicit, :BlockNone),
        Gemini::SafetySetting.new(:HarmCategoryHateSpeech, :BlockNone),
        Gemini::SafetySetting.new(:HarmCategoryHarassment, :BlockNone),
        Gemini::SafetySetting.new(:HarmCategoryDangerousContent, :BlockNone),
        Gemini::SafetySetting.new(:HarmCategoryCivicIntegrity, :BlockNone),
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
            type: :object,
            properties: {
              "prompt" => Gemini::Schema.new(
                type: :string,
                description: "Description of what you want to create.",
              ),
            },
            required: ["prompt"],
          )
        ),
      ])],
    }

    getter chat : Models::Chat
    getter messages : Messages
    # Send media using telegram API
    getter media = [] of Tourmaline::InputMediaPhoto

    def initialize(chat_id)
      @chat = Models::Chat.find!(chat_id)
      @model = Gemini::GenerativeModel.new(**MODEL_CONFIG, system_instruction: Gemini::Content.new(system_role))
      @messages = Messages.new("turquoise:eloquent:chat:#{chat.id}").load
    end

    def generate(text : String) : String
      messages.push Gemini::Content.new(text, :user)
      response = @model.generate_content(messages.value)

      function_calling_handler pointerof(response)
      messages.push Gemini::Content.new(response.text, :model)

      response.text
    rescue ex : Gemini::MissingCandidatesException
      messages.rollback
      "Não posso responder sua mensagem: '#{ex.block_reason.to_s.underscore.titleize(underscore_to_space: true)}'" # TODO: internationalization
    rescue ex : Gemini::MissingContentException
      messages.rollback
      "Não posso responder sua mensagem: '#{ex.finish_reason.to_s.underscore.titleize(underscore_to_space: true)}'" # TODO: internationalization
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
        messages.push Gemini::Content.new(response.value.parts, :model)
        messages.push Gemini::Content.new(function_parts, :function)

        res = @model.generate_content(messages.value)
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

    struct Messages
      getter? active = false
      property current = [] of Gemini::Content
      property future = [] of Gemini::Content

      def initialize(@key : String)
      end

      def transaction
        @active = true
      end

      def rollback
        future.clear
        @active = false
      end

      def commit
        unless active? # Cancelled
          Log.warn { "eloquent -- Attempt to commit without active transaction" }
          return
        end

        current.concat future
        Redis.rpush @key, future.map(&.to_json)
        Redis.ltrim @key, -MAX_MESSAGES, -1
        future.clear
        @active = false
      end

      def transaction(&)
        transaction
        yield
        commit
      end

      def value
        current + future
      end

      def push(message)
        unless active? # Cancelled
          Log.warn { "eloquent -- Cannot push without active transaction" }
          return
        end

        future.push message
      end

      # Alias to `#push`
      def <<(message)
        push(message)
      end

      # Load messages from persistent memory to volatile memory
      def load
        Redis.lrange(@key, 0, -1).each do |message|
          current << Gemini::Content.from_json message.as(String)
        end
        self
      end

      # Remove messages from volatile memory
      def clear
        future.clear
        current.clear
        self
      end

      # Remove messages from persistent memory
      def delete
        Redis.del @key
        self
      end
    end
  end
end
