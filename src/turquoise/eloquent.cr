require "json"
require "./eloquent/api"

# require "./eloquent/functions"

module Turquoise
  class Eloquent
    ENDPOINT     = "#{ENV["ELOQUENT_HOST_URL"]}/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i

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
      data << system_role
      Redis.set "turquoise:eloquent:chat:#{chat_id}", data.messages.to_json
    end

    def request
      Log.debug { "eloquent -- #{chat_id}: #{data.messages}" }
      headers = HTTP::Headers{"Authorization" => "Bearer #{ENV["ELOQUENT_API_KEY"]}", "Content-Type" => "application/json"}
      response = HTTP::Client.post(ENDPOINT, body: data.to_json, headers: headers)

      if response.success?
        Chat::Completion.from_json(response.body)
      else
        raise "eloquent -- #{response.status_code} #{response.status}: #{response.body}"
      end
    end

    def completion(text : String) : Chat::Completion::Message
      data << Chat::Completion::Message.new :user, text
      message = request.choices.first[:message]
      data << message

      # Process Function calling
      # https://platform.openai.com/docs/guides/gpt/function-calling
      if (function = message.function_call) && message.content.nil?
        case function[:name]?
        when "send_selfie"
          send_selfie
        when "send_pet_image"
          send_pet_image function[:arguments]
        end
      end

      Redis.set "turquoise:eloquent:chat:#{chat_id}", data.messages.to_json
      data.messages.last
    end

    def system_role
      chat = Models::Chat.find!(chat_id)

      if chat.type == "private"
        Chat::Completion::Message.new :system, ENV["ELOQUENT_ROLE_PRIVATE"]
      else
        Chat::Completion::Message.new :system, ENV["ELOQUENT_ROLE_GROUP"]
      end
    end

    # Gets a random selfie and uses the filename as image description.
    def send_selfie
      if file = random_selfie
        description = File.basename(file.path, ".jpg")

        data << Chat::Completion::Message.new :function, %({"description": "#{description}"}), name: "send_selfie"
        message = request.choices.first[:message]
        message.photo = file
        data << message
      end
    end

    # Gets a random pet image with breed using `Turquoise::Pets`.
    # `args` use JSON schema provided by ChatGPT.
    def send_pet_image(args)
      pet = NamedTuple(pet: Pets).from_json(args)[:pet]
      image = pet.random_with_breed(mime_types: "jpg,png")

      data << Chat::Completion::Message.new :function, %({"breed": "#{image.breeds_to_list}"}), name: "send_pet_image"
      message = request.choices.first[:message]
      message.photo = image.url
      data << message
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      image = Dir.glob(File.join(dir, "/*.jpg")).sample

      File.open(image, "rb") if File.exists?(image)
    end

    struct RequestData
      include JSON::Serializable

      property model = "gpt-3.5-turbo-0613"
      property messages = Deque(Chat::Completion::Message).new(MESSAGES_MAX)
      property temperature = 0.9
      property functions = [{
        name:        "send_selfie",
        description: "Send photo of yourself when the user requests it",
        parameters:  {type: "object", properties: {} of Nil => Nil},
      }, {
        name:        "send_pet_image",
        description: "Send a random image of a cat or dog",
        parameters:  {
          type:       "object",
          properties: {
            pet: {
              type:        "string",
              description: "Choose between cat or dog image",
              enum:        ["cat", "dog"],
            },
          },
          required: ["pet"],
        },
      }]

      def initialize
      end

      # Keep maximum size and system message
      def <<(message : Chat::Completion::Message)
        messages.delete_at(1) if messages.size >= MESSAGES_MAX
        messages << message
      end
    end
  end
end
