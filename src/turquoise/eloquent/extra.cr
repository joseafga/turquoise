module Turquoise
  class Eloquent
    # Image Model generation for custom image function calling
    struct ImageModel
      struct Request
        include JSON::Serializable
        property prompt : String
        property num_steps : Int32?

        def initialize(@prompt, @num_steps = nil)
        end
      end

      struct Response
        include JSON::Serializable
        getter result : Result
        getter? success : Bool
        getter errors : Array(Error)

        struct Result
          include JSON::Serializable
          property! image : String

          def to_tempfile
            File.tempfile("turquoise-", suffix: ".png") do |io|
              Base64.decode(image, io)
            end
          end
        end

        struct Error
          include JSON::Serializable
          getter message : String
          getter code : Int32

          def to_s
            "#{code}: #{message}"
          end
        end
      end
    end
  end
end
