module Turquoise
  class Eloquent
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
      dir = File.expand_path("../../../img/pictures/", __DIR__)
      Dir.glob(File.join(dir, "/*.jpg")).sample
    end
  end
end
