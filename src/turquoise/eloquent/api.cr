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
            Function
          end

          property role : Role
          property name : String?
          @[JSON::Field(emit_null: true)]
          property content : String?
          property function_call : NamedTuple(name: String, arguments: String)?
          @[JSON::Field(ignore: true)]
          property photo : String?

          def initialize(@role, @content, @name = nil, @photo = nil)
          end

          def escape_md
            Helpers.escape_md content
          end

          def to_s
            content
          end
        end
      end
    end
  end
end
