require "json"
require "./eloquent/api"

module Turquoise
  class Eloquent
    MODEL        = "@hf/thebloke/openhermes-2.5-mistral-7b-awq"
    ENDPOINT     = "https://api.cloudflare.com/client/v4/accounts/#{ENV["ELOQUENT_ACCOUNT_ID"]}/ai/run/#{MODEL}"
    MAX_MESSAGES = 10
    MAX_TOKENS   = nil # Defaults is 256
    HEADERS      = HTTP::Headers{"Authorization" => "Bearer #{ENV["ELOQUENT_API_KEY"]}", "Content-Type" => "application/json"}

    getter chat_id : Int64
    property data : RequestData

    def initialize(chat_id)
      @chat_id = chat_id
      @data = RequestData.new

      if messages = Redis.get("turquoise:eloquent:chat:#{@chat_id}")
        @data.messages = data.messages.class.from_json(messages)
      else
        clear
      end
    end

    # Reset chat messages.
    def clear
      data.messages.clear
      Redis.del "turquoise:eloquent:chat:#{chat_id}"
    end

    private def request(body : RequestData)
      # Insert system message to IA acts like
      system_message = Chat::Completion::Message.new :system, system_role
      body.messages = body.messages.dup.insert 0, system_message

      Log.debug { "eloquent -- #{chat_id}: #{body.to_pretty_json}" }
      response = HTTP::Client.post ENDPOINT, body: body.to_json, headers: HEADERS

      raise "eloquent -- #{response.status_code} #{response.status}: #{response.body}" unless response.success?
      Chat::Result.from_json response.body
    end

    def completion(text : String) : Chat::Completion::Message
      data << Chat::Completion::Message.new :user, text
      res = request(data)

      # When some error happen, skip store data but show message to user
      if res.errors.any?
        return Chat::Completion::Message.new :assistant, res.errors.join('\n')
      end

      message = process(Chat::Completion::Message.new :assistant, res.result[:response])

      data << message
      Redis.set "turquoise:eloquent:chat:#{chat_id}", data.messages.to_json
      message.sanitize
      message
    end

    def process(message : Chat::Completion::Message)
      if match = message.to_s.match(/%([A-Z0-9 _]*)%/)
        case match[1]
        when "SELFIE"
          send_selfie pointerof(message)
        else
          # TODO: Image Generation
          message.content = "TODO: Image Generation (#{match[1]})"
        end
      end

      message
    end

    # TODO: internationalization
    def system_role
      chat = Models::Chat.find!(chat_id)

      if chat.type == "private"
        "#{ENV["ELOQUENT_ROLE"]} You are in a private chat."
      else
        "#{ENV["ELOQUENT_ROLE"]} You are in a group chatting with friends."
      end
    end

    # Gets a random pet image with breed using `Turquoise::Pets`.
    # `args` use JSON schema provided by ChatGPT.
    def send_cat_or_dog(args)
      pet = Pets::Images.parse(JSON.parse(args)["pet"].as_s)
      image = pet.random_with_breed(mime_types: "jpg,png")

      data << Chat::Completion::Message.new :function, %({"breed": "#{image.breeds_to_list}"}), name: "send_cat_or_dog"
      message = request(data).choices.first[:message]
      message.photo = image.url
      data << message
    end

    def send_selfie(message : Chat::Completion::Message*)
      if file = random_selfie
        description = File.basename(file.path, ".jpg")

        # TODO: internationalization
        selfie = RequestData.new
        selfie << Chat::Completion::Message.new :user, "Reescreva com suas palavras: #{description}."
        res = request(selfie).result[:response]

        # Store fake expected response based on image description for best future responses
        message.value = Chat::Completion::Message.new :assistant, "%SELFIE%\n#{res}", photo: file
      end
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      image = Dir.glob(File.join(dir, "/*.jpg")).sample

      File.open(image, "rb") if File.exists?(image)
    end
  end
end
