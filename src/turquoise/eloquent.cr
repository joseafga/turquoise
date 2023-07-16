require "json"
require "http/client"

module Turquoise
  class Eloquent
    struct RequestData
      include JSON::Serializable

      property model = "gpt-3.5-turbo"
      property messages = [] of NamedTuple(role: String, content: String)
      property temperature = 1.2

      def initialize
      end
    end

    ENDPOINT     = "https://api.openai.com/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i
    BUFFER_MAX   = ENV["ELOQUENT_BUFFER_MAX"].to_i
    @@buffer = {} of Int64 => Eloquent

    property chat : Models::Chat
    property data = RequestData.new

    def initialize(chat_id)
      @chat = Models::Chat.find! chat_id
      @data.messages << {role: "system", content: role_per_type}
    end

    def role_per_type
      if chat.type == "private"
        ENV["ELOQUENT_PRIVATE_ROLE"]
      else
        ENV["ELOQUENT_GROUP_ROLE"]
      end
    end

    def message(text : String)
      headers = HTTP::Headers{"Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}", "Content-Type" => "application/json"}
      push_message role: "user", content: text

      response = HTTP::Client.post(ENDPOINT, body: data.to_json, headers: headers)

      if response.success?
        response_data = JSON.parse(response.body)
        reply = response_data["choices"][0]["message"]["content"].to_s
        push_message role: "assistant", content: reply

        Log.debug { "eloquent -- #{chat.id}: #{data.messages}" }
        reply
      else
        raise "eloquent -- #{response.status_code} #{response.status}"
      end
    end

    # Keep maximum size and system message
    private def push_message(**kwargs)
      data.messages.delete_at(1) if data.messages.size >= MESSAGES_MAX
      data.messages << kwargs
    end

    # TODO: Save old chats in redis and retrieve it when needed
    def self.instance(chat_id)
      return @@buffer[chat_id] if @@buffer.has_key?(chat_id)

      @@buffer.shift if @@buffer.size >= BUFFER_MAX
      @@buffer[chat_id] = new(chat_id)
    end
  end
end
