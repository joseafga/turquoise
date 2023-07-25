require "json"
require "./eloquent/api"

module Turquoise
  class Eloquent
    ENDPOINT     = "#{ENV["ELOQUENT_HOST_URL"]}/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i
    BUFFER_MAX   = ENV["ELOQUENT_BUFFER_MAX"].to_i
    @@buffer = {} of Int64 => Eloquent

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

    # reset chat messages
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
        when "send_selfie"
          send_selfie
        when "send_cat"
          send_cat
        when "send_dog"
          send_dog
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

    def send_selfie
      data << Chat::Completion::Message.new :function, "Cute portrait", name: "send_selfie"
      message = request.choices.first[:message]
      message.photo = random_selfie
      data << message
    end

    def send_cat
      data << Chat::Completion::Message.new :function, "Fluffy cat", name: "send_cat"
      message = request.choices.first[:message]
      message.photo = Pets::Cat.random
      data << message
    end

    def send_dog
      data << Chat::Completion::Message.new :function, "Beautiful dog", name: "send_dog"
      message = request.choices.first[:message]
      message.photo = Pets::Dog.random
      data << message
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      picture = Dir.glob(File.join(dir, "/turquesa_*.jpg")).sample

      File.open(picture, "rb") if File.exists? picture
    end

    # TODO: Save old chats in redis and retrieve it when needed
    def self.instance(chat_id)
      return @@buffer[chat_id] if @@buffer.has_key?(chat_id)

      @@buffer.shift if @@buffer.size >= BUFFER_MAX
      @@buffer[chat_id] = new(chat_id)
    end

    struct RequestData
      include JSON::Serializable

      property model = "gpt-3.5-turbo-0613"
      property messages = [] of Chat::Completion::Message
      property temperature = 1.2
      property functions = [{
        name:        "send_selfie",
        description: "Send portraits of yourself",
        parameters:  {type: "object", properties: {} of String => String},
      }, {
        name:        "send_cat",
        description: "Send picture of a cat",
        parameters:  {type: "object", properties: {} of String => String},
      }, {
        name:        "send_dog",
        description: "Send picture of a dog",
        parameters:  {type: "object", properties: {} of String => String},
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
