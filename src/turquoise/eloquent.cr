require "json"
require "./eloquent/api"

module Turquoise
  class Eloquent
    ENDPOINT     = "#{ENV["ELOQUENT_HOST_URL"]}/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i

    property chat : Models::Chat
    property data : RequestData

    def initialize(chat_id)
      @chat = Models::Chat.find! chat_id
      @data = RequestData.new

      if messages = Redis.get("turquoise:eloquent:chat:#{@chat.id}")
        @data.messages = data.messages.class.from_json(messages)
      else
        clear
      end
    end

    # Reset chat messages.
    def clear
      data.messages.clear
      data << system_role
      Redis.set "turquoise:eloquent:chat:#{chat.id}", data.messages.to_json
    end

    def request
      Log.debug { "eloquent -- #{chat.id}: #{data.messages}" }
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
      if function = message.function_call
        case function[:name]?
        when "attach_selfie"
          attach_selfie
        when "attach_pet_picture"
          attach_pet_picture function[:arguments]
        end
      end

      Redis.set "turquoise:eloquent:chat:#{chat.id}", data.messages.to_json
      data.messages.last
    end

    def system_role
      if chat.type == "private"
        Chat::Completion::Message.new :system, ENV["ELOQUENT_ROLE_PRIVATE"]
      else
        Chat::Completion::Message.new :system, ENV["ELOQUENT_ROLE_GROUP"]
      end
    end

    # Gets a random selfie and uses the filename as image description
    def attach_selfie
      if file = random_selfie
        data << Chat::Completion::Message.new :function, %({"description": "#{File.basename(file.path, ".jpg")}"}), name: "attach_selfie"
        message = request.choices.first[:message]
        message.photo = file
        data << message
      end
    end

    def attach_pet_picture(args)
      pet = NamedTuple(pet: Pets).from_json(args)[:pet]
      image = pet.random_with_breed(mime_types: "jpg,png")
      breeds = image[:breeds].join(", ") { |breed| breed[:name] }

      data << Chat::Completion::Message.new :function, %({"breed": "#{breeds}"}), name: "attach_pet_picture"
      message = request.choices.first[:message]
      message.photo = image[:url]
      data << message
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      picture = Dir.glob(File.join(dir, "/*.jpg")).sample

      File.open(picture, "rb") if File.exists? picture
    end

    struct RequestData
      include JSON::Serializable

      property model = "gpt-3.5-turbo-0613"
      property messages = [] of Chat::Completion::Message
      property temperature = 1.2
      property functions = [{
        name:        "attach_selfie",
        description: "Send picture of yourself",
        parameters:  {type: "object", properties: {} of Nil => Nil},
      }, {
        name:        "attach_pet_picture",
        description: "Send picture of a cat or dog",
        parameters:  {
          type:       "object",
          properties: {
            pet: {
              type:        "string",
              description: "Choose between cat or dog picture",
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
