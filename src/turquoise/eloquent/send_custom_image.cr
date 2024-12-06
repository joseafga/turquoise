require "base64"

module Turquoise
  class Eloquent
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

    struct ImageModel
      struct Request
        include JSON::Serializable
        property prompt : String
        property num_steps : Int32?

        def initialize(@prompt, @num_steps = nil)
        end
      end

      struct Response
        include JSON::Serializable
        getter result : Result
        getter? success : Bool
        getter errors : Array(Error)

        struct Result
          include JSON::Serializable
          property! image : String

          def to_tempfile
            File.tempfile("turquoise-", suffix: ".png") do |io|
              Base64.decode(image, io)
            end
          end
        end

        struct Error
          include JSON::Serializable
          getter message : String
          getter code : Int32

          def to_s
            "#{code}: #{message}"
          end
        end
      end
    end
  end
end
