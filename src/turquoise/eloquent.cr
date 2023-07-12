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
        @messages << {role: "system", content: ENV["ELOQUENT_ROLE"]}
      end
    end

    ENDPOINT     = "https://api.openai.com/v1/chat/completions"
    MESSAGES_MAX = ENV["ELOQUENT_MESSAGE_MAX"].to_i
    BUFFER_MAX   = ENV["ELOQUENT_BUFFER_MAX"].to_i
    @@buffer = {} of Int64 => Eloquent
    @@headers = HTTP::Headers{
      "Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}",
      "Content-Type"  => "application/json",
    }

    property chat_id : Int64
    property data = RequestData.new

    def initialize(@chat_id)
    end

    def message(text : String)
      push_message({role: "user", content: text})
      response = HTTP::Client.post(ENDPOINT, body: data.to_json, headers: @@headers)
      response_data = JSON.parse(response.body)

      if response.status.success?
        reply = response_data["choices"][0]["message"]["content"].to_s
        push_message({role: "assistant", content: reply})

        Log.debug { "eloquent -- #{chat_id}: #{data.messages}" }
        reply
      else
        raise "eloquent -- #{response.status_code} #{response.status}"
      end
    end

    # Keep maximum size and system message
    private def push_message(value)
      data.messages.delete_at(1) if data.messages.size >= MESSAGES_MAX
      data.messages << value
    end

    # TODO: Save old chats in redis and retrieve it when needed
    def self.instance(chat_id)
      return @@buffer[chat_id] if @@buffer.has_key?(chat_id)

      @@buffer.shift if @@buffer.size >= BUFFER_MAX
      @@buffer[chat_id] = new(chat_id)
    end
  end
end
