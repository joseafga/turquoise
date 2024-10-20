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
            Tool
          end

          property role : Role
          @[JSON::Field(emit_null: true)]
          property content : String
          @[JSON::Field(ignore: true)]
          property photo : String | File | Nil

          def initialize(@role, @content = "", @photo = nil)
          end

          def escape_md
            Helpers.escape_md content
          end

          def to_s
            content.to_s
          end
        end
      end

      struct Result
        include JSON::Serializable
        property result : NamedTuple(response: String?, tool_calls: Array(Tool::Call) | Nil)
        property? success : Bool
        property errors : Array(NamedTuple(message: String))
        property messages : Array(String)
      end

      struct Request
        include JSON::Serializable
        property messages : Deque(Chat::Completion::Message)
        property max_tokens : Int32?
        property temperature : Int32?
        property top_p : Int32?
        property top_k : Int32?
        property seed : Int32?
        property repetition_penalty : Int32?
        property frequency_penalty : Int32?
        property presence_penalty : Int32?
        property tools

        def initialize
          @messages = Deque(Chat::Completion::Message).new(MAX_MESSAGES)
          @max_tokens = MAX_TOKENS
          @tools = [] of Tool
        end

        # Keep maximum size and system message
        def <<(message : Chat::Completion::Message)
          messages.shift if messages.size >= MAX_MESSAGES
          messages.push message
        end
      end

      struct Tool
        include JSON::Serializable
        property name : String
        property description : String
        property parameters

        def initialize(@name, @description, @parameters = {
                         type:       "object",
                         properties: {} of String => NamedTuple(type: String, description: String),
                         required:   [] of String,
                       })
        end

        struct Call
          include JSON::Serializable
          property arguments : Hash(String, String)
          property name : String
        end
      end
    end

    module Prompt
      struct Request
        include JSON::Serializable
        property prompt : String
        property image : File?
        property mask : File?
        property num_steps : Int32?
        property strength : Int32?
        property guidance : Float32?

        def initialize(@prompt, @num_steps = nil)
        end
      end
    end
  end
end
