require "./eloquent/messages"
require "./eloquent/extra"

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
                description: "Description of the image you want to generate. Translated to English.",
              ),
              "num_steps" => Gemini::Schema.new(
                type: :integer,
                description: "Image quality from 1 to 8. 1 is low quality, 8 is high, default is 4.",
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
      !!media.find(&.caption)
    end

    def generate(text : String) : String
      messages.push Gemini::Content.new(text, role: :user)
      response = @model.generate_content(messages.value)

      function_calling_handler pointerof(response)
      messages.push Gemini::Content.new(response.text, role: :model)

      response.text
    rescue ex : Gemini::MissingCandidatesException
      _error_message(ex.block_reason)
    rescue ex : Gemini::MissingContentException
      _error_message(ex.finish_reason)
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
        messages.push Gemini::Content.new(response.value.parts, role: :model)
        messages.push Gemini::Content.new(function_parts, role: :function)

        res = @model.generate_content(messages.value)
        # Message will receive text part of function calling response
        response.value = res
      end
    end

    def send_selfie_image(func_call : Gemini::FunctionCall) : Gemini::Part
      begin
        selfie_path = random_selfie
        description = File.basename(selfie_path, ".jpg")
        response = %({"success": "true", "description": "#{description}."})

        media << Tourmaline::InputMediaPhoto.new(media: selfie_path)
      rescue
        response = %({"success": "false"})
      end

      Gemini::Part.new(Gemini::FunctionResponse.new(
        func_call.name,
        JSON.parse(response)
      ))
    end

    def random_selfie : String
      dir = File.expand_path("../../img/pictures/", __DIR__)
      Dir.glob(File.join(dir, "/*.jpg")).sample
    end

    def send_custom_image(func_call : Gemini::FunctionCall) : Gemini::Part
      begin
        args = func_call.args.not_nil!
        prompt = args["prompt"].as_s
        if num_steps = args["num_steps"]?.try &.as_i
          num_steps = nil unless (1..8).includes?(num_steps)
        end

        result = request_custom_image(ImageModel::Request.new(prompt, num_steps))
        response = %({"success": "true"})

        media << Tourmaline::InputMediaPhoto.new(
          media: result.to_tempfile.path,
          caption: %("#{prompt}")
        )
      rescue
        response = %({"success": "false"})
      end

      Gemini::Part.new(Gemini::FunctionResponse.new(
        func_call.name,
        JSON.parse(response)
      ))
    end

    private def request_custom_image(body : ImageModel::Request)
      Log.debug { "eloquent -- Requesting -> #{chat.id}: #{body.to_pretty_json}" }
      json = HTTP::Client.post(
        "https://api.cloudflare.com/client/v4/accounts/#{ENV["CF_ACCOUNT_ID"]}/ai/run/@cf/black-forest-labs/flux-1-schnell",
        body: body.to_json,
        headers: HTTP::Headers{"Authorization" => "Bearer #{ENV["CF_API_KEY"]}", "Content-Type" => "application/json"}
      )

      response = ImageModel::Response.from_json(json.body)

      return response.result if response.success?
      raise "eloquent -- Unsuccessfully request. #{response.errors.join(",", &.to_s)}"
    end

    private def _error_message(reason) : String
      messages.rollback
      # TODO: internationalization
      "Não posso responder sua mensagem: *#{reason.to_s.underscore.titleize(underscore_to_space: true)}*"
    end
  end
end
