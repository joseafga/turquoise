require "./eloquent/api"

module Turquoise
  class Eloquent
    ENDPOINT     = "#{ENV["ELOQUENT_HOST_URL"]}/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i
    BUFFER_MAX   = ENV["ELOQUENT_BUFFER_MAX"].to_i
    @@buffer = {} of Int64 => Eloquent

    property chat : Models::Chat
    property data = RequestData.new

    def initialize(chat_id)
      @chat = Models::Chat.find! chat_id
      @data << system_role
    end

    def request
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
        end
      end

      Log.debug { "eloquent -- #{chat.id}: #{data.messages}" }
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
      data << Chat::Completion::Message.new :function, %({"description": "Cute portrait"}), name: "send_selfie"
      message = request.choices.first[:message]
      message.photo = random_selfie
      data << message
    end

    def random_selfie
      dir = File.expand_path("../../img/pictures/", __DIR__)
      picture = Dir.glob(File.join(dir, "/turquesa_*.jpg")).sample

      return picture if File.exists? picture
      nil
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
        description: "Upload portraits of Turquesa",
        parameters:  {
          type: "object", properties: {} of String => String,
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
