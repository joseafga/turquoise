require "json"

module Turquoise
  class Eloquent
    module Chat
      struct Completion
        include JSON::Serializable

        property id : String
        property object : String
        property created : Int32
        property model : String
        property choices : Array(NamedTuple(index: Int32, message: Message, finish_reason: String))
        property usage : NamedTuple(prompt_tokens: Int32, completion_tokens: Int32, total_tokens: Int32)

        struct Message
          include JSON::Serializable

          enum Role
            System
            User
            Assistant
          end

          property role : Role
          @[JSON::Field(emit_null: true)]
          property content : String?
          @[JSON::Field(ignore: true)]
          property photo : String | File | Nil

          def initialize(@role, @content, @photo = nil)
          end

          def escape_md
            Helpers.escape_md content
          end

          # Remove all keywords from reponses
          def sanitize(replace = "")
            @content = to_s.gsub(/%([A-Z0-9 _]*)%/, replace).strip
          end

          def to_s
            content.to_s
          end
        end
      end

      struct Result
        include JSON::Serializable

        property result : NamedTuple(response: String)
        property success : Bool
        property errors : Array(NamedTuple(message: String))
        property messages : Array(String)
      end
    end

    struct RequestData
      include JSON::Serializable
      property messages : Deque(Chat::Completion::Message)
      property max_tokens : Int32?

      def initialize
        @messages = Deque(Chat::Completion::Message).new(MAX_MESSAGES)
        @max_tokens = MAX_TOKENS
      end

      # Keep maximum size and system message
      def <<(message : Chat::Completion::Message)
        messages.shift if messages.size >= MAX_MESSAGES
        messages.push message
      end
    end
  end
end
