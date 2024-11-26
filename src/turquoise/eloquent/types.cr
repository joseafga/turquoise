require "json"
require "./safety"

module Turquoise
  class Eloquent
    # Google Gemini API
    module Chat
      # Generates a model response given an input.
      #
      # See: https://ai.google.dev/api/generate-content#method:-models.generatecontent
      struct Request
        include JSON::Serializable
        # _Optional_. Developer set `system instruction(s)`. Currently, text only.
        #
        # See: https://ai.google.dev/gemini-api/docs/system-instructions
        @[JSON::Field(key: "systemInstruction")]
        property system_instruction : Chat::Content?

        # _Required_. The content of the current conversation with the model.
        # For single-turn queries, this is a single instance. For multi-turn queries
        # like chat, this is a repeated field that contains the conversation history
        # and the latest request.
        property contents : Deque(Chat::Content)

        # _Optional_. A list of Tools the Model may use to generate the next response.
        property tools : Array(Tool)?

        # _Optional_. Tool configuration for any Tool specified in the request. Refer
        # to the Function calling guide for a usage example.
        @[JSON::Field(key: "toolConfig")]
        property tool_config : ToolConfig?

        # _Optional_. A list of unique SafetySetting instances for blocking unsafe content.
        @[JSON::Field(key: "safetySettings")]
        property safety_settings : Array(SafetySetting)?

        # _Optional_. Configuration options for model generation and outputs.
        @[JSON::Field(key: "generationConfig")]
        property generation_config : GenerationConfig?

        # _Optional_. The name of the content [cached](https://ai.google.dev/gemini-api/docs/caching)
        # to use as context to serve the prediction.
        @[JSON::Field(key: "cachedContent")]
        property cached_content : String?

        # Configuration parameters are optional and non-initialized, so they must be
        # defined later
        def initialize(@system_instruction = nil, @tools = nil, @cached_content = nil)
          @contents = Deque(Chat::Content).new(MAX_MESSAGES)
        end

        # Keep maximum size and system message
        def <<(message : Chat::Content)
          contents.shift if contents.size >= MAX_MESSAGES
          contents.push message
        end

        # Configuration options for model generation and outputs. Not all parameters
        # are configurable for every model.
        #
        # See: https://ai.google.dev/api/generate-content#generationconfig
        struct GenerationConfig
          include JSON::Serializable
          # Number of generated responses to return.
          @[JSON::Field(key: "candidateCount")]
          property candidate_count : Int32?

          # The set of character sequences (up to 5) that will stop output generation.
          # If specified, the API will stop at the first appearance of a stop sequence.
          # The stop sequence will not be included as part of the response.
          @[JSON::Field(key: "stopSequences")]
          property stop_sequences : Array(String)?

          # Controls the randomness of the output.
          # Values can range from `[0.0,1.0]`, inclusive. A value closer to `1.0`
          # will produce responses that are more varied and creative, while a value
          # closer to `0.0` will typically result in more straightforward responses
          # from the model.
          property temperature : Float64?

          # The maximum number of tokens to include in a candidate.
          # If unset, this will default to output_token_limit specified in the model's
          # specification.
          @[JSON::Field(key: "maxOutputTokens")]
          property max_output_tokens : Int32?

          # The maximum number of tokens to consider when sampling.
          # The model uses combined Top-k and nucleus sampling. Top-k sampling
          # considers the set of top_k most probable tokens. Defaults to 40.
          @[JSON::Field(key: "topK")]
          property top_k : Int32?

          # The maximum cumulative probability of tokens to consider when sampling.
          # The model uses combined Top-k and nucleus sampling.
          # Tokens are sorted based on their assigned probabilities so that only the
          # most likely tokens are considered. Top-k sampling directly limits the
          # maximum number of tokens to consider, while Nucleus sampling limits number
          # of tokens based on the cumulative probability.
          @[JSON::Field(key: "topP")]
          property top_p : Float64?

          # Output response mimetype of the generated candidate text.
          # Supported mimetype:
          # * __text/plain__: (default) Text output.
          # * __application/json__: JSON response in the candidates.
          @[JSON::Field(key: "responseMimeType")]
          property response_mime_type : String?

          # TODO: Specifies the format of the JSON requested if response_mime_type is
          # `application/json`.
          # @[JSON::Field(key: "responseSchema")]
          # property response_schema : ResponseSchema

          def initialize(
            @stop_sequences = nil,
            @temperature = nil,
            @max_output_tokens = nil,
            @top_k = nil,
            @top_p = nil
          )
          end
        end
      end

      # Response from the model supporting multiple candidate responses.
      #
      # See: https://ai.google.dev/api/generate-content#generatecontentresponse
      struct Result
        include JSON::Serializable
        # Candidate responses from the model.
        getter candidates : Array(Candidate)

        # Returns the prompt's feedback related to the content filters.
        @[JSON::Field(key: "promptFeedback")]
        getter prompt_feedback : PromptFeedback?

        # _Output only_. Metadata on the generation requests' token usage.
        @[JSON::Field(key: "usageMetadata")]
        getter usage_metadata : UsageMetadata?

        @[JSON::Field(key: "modelVersion")]
        getter model_version : String?

        # A response candidate generated from the model.
        #
        # See: https://ai.google.dev/api/generate-content#candidate
        struct Candidate
          include JSON::Serializable
          # _Output only_. Generated content returned from the model.
          # This is not optional but some finish reasons respond without a content field.
          getter content : Chat::Content?

          # _Optional_. _Output only_. The reason why the model stopped generating tokens.
          # If empty, the model has not stopped generating tokens.
          @[JSON::Field(key: "finishReason")]
          getter finish_reason : FinishReason?

          # List of ratings for the safety of a response candidate.
          # There is at most one rating per category.
          @[JSON::Field(key: "safetyRatings")]
          getter safety_ratings : Array(SafetyRating)

          # TODO: citationMetadata - object (CitationMetadata)
          # _Output only_. Citation information for model-generated candidate.
          # This field may be populated with recitation information for any text
          # included in the content. These are passages that are "recited" from
          # copyrighted material in the foundational LLM's training data.

          # _Output only_. Token count for this candidate.
          @[JSON::Field(key: "tokenCount")]
          getter token_count : Int32 = 0

          # TODO: avgLogprobs - number
          # _Output only_.
          # TODO: logprobsResult - object (LogprobsResult)
          # _Output only_. Log-likelihood scores for the response tokens and top tokens

          # _Output only_. Index of the candidate in the list of response candidates.
          getter index : Int32 = 0

          def content!
            content.not_nil!
          end
        end

        # A set of the feedback metadata the prompt specified in
        # `Turquoise::Eloquent::Chat::Content`.
        #
        # See: https://ai.google.dev/api/generate-content#PromptFeedback
        struct PromptFeedback
          include JSON::Serializable
          # _Optional_. If set, the prompt was blocked and no candidates are returned.
          @[JSON::Field(key: "blockReason")]
          getter block_reason : BlockReason?

          # Ratings for safety of the prompt. There is at most one rating per category.
          @[JSON::Field(key: "safetyRatings")]
          getter safety_ratings : Array(SafetyRating)
        end

        # Metadata on the generation request's token usage.
        #
        # See: https://ai.google.dev/api/generate-content#UsageMetadata
        struct UsageMetadata
          include JSON::Serializable
          # Number of tokens in the prompt. When cachedContent is set, this is still
          # the total effective prompt size meaning this includes the number of tokens
          # in the cached content.
          @[JSON::Field(key: "promptTokenCount")]
          getter prompt_token_count : Int32?

          # Number of tokens in the cached part of the prompt (the cached content)
          @[JSON::Field(key: "cachedContentTokenCount")]
          getter cached_content_token_count : Int32?

          # Total number of tokens across all the generated response candidates.
          @[JSON::Field(key: "candidatesTokenCount")]
          getter candidates_token_count : Int32?

          # Total token count for the generation request (prompt + response candidates).
          @[JSON::Field(key: "totalTokenCount")]
          getter total_token_count : Int32
        end
      end

      # Tool details that the model may use to generate response.
      #
      # See: https://ai.google.dev/api/caching#Tool
      struct Tool
        include JSON::Serializable
        # _Optional_. A list of `FunctionDeclarations` available to the model that can
        # be used for function calling.
        @[JSON::Field(key: "functionDeclarations")]
        property function_declarations : Array(FunctionDeclaration)?

        # TODO: _Optional_. Enables the model to execute code as part of generation.
        # @[JSON::Field(key: "codeExecution")]
        # property code_execution : CodeExecution

        def initialize(@function_declarations = nil)
        end
      end

      # Structured representation of a function declaration as defined by the
      # OpenAPI 3.03 specification.
      #
      # See: https://ai.google.dev/api/caching#FunctionDeclaration
      struct FunctionDeclaration
        include JSON::Serializable
        # _Required_. The name of the function.
        property name : String
        # _Required_. A brief description of the function.
        property description : String
        # _Optional_. Describes the parameters to this function.
        property parameters : Schema?

        def initialize(@name, @description, @parameters = nil)
        end

        def initialize(@name, @description, parameters : NamedTuple)
          @parameters = Schema.new(**parameters)
        end

        # Reduced scheme
        class Schema
          include JSON::Serializable
          # _Required_. Data type.
          property type : Type
          # _Optional_. The format of the data.
          # Supported formats:
          # * __NUMBER__: float, double
          # * __INTEGER__: int32, int64
          # * __STRING__: enum
          property format : String?
          # _Optional_. A brief description of the parameter. This could contain
          # examples of use. Parameter description may be formatted as Markdown.
          property description : String?
          # _Optional_. Indicates if the value may be null.
          property nullable : Bool?
          # _Optional_. Possible values of the element of `Type::STRING` with enum
          # format. For example we can define an Enum Direction as:
          #
          # ```
          # {
          #   type: STRING,
          #   format: enum,
          #   enum: ["EAST", NORTH", "SOUTH", "WEST"]
          # }
          # ```
          @[JSON::Field(key: "enum")]
          property enumeration : Array(String)?
          # _Optional_. Maximum number of the elements for `Type::ARRAY`
          @[JSON::Field(key: "maxItems")]
          property max_items : String?
          # _Optional_. Minimum number of the elements for `Type::ARRAY`
          @[JSON::Field(key: "minItems")]
          property min_items : String?
          # _Optional_. Properties of `Type`
          property properties : Hash(String, Schema)?
          # _Optional_. Required properties of `Type`
          property required : Array(String)?
          # _Optional_. Schema of the elements of `Type::ARRAY`.
          property items : Schema?

          def initialize(
            @type,
            @format = nil,
            @description = nil,
            @nullable = nil,
            @enumeration = nil,
            @max_items = nil,
            @min_items = nil,
            @properties = nil,
            @required = nil,
            @items = nil
          )
          end
        end

        # Type contains the list of OpenAPI data types as defined by
        #
        # See: https://spec.openapis.org/oas/v3.0.3#data-types
        enum Type
          TYPE_UNSPECIFIED # Not specified, should not be used.
          STRING           # String type.
          NUMBER           # Number type.
          INTEGER          # Integer type.
          BOOLEAN          # Boolean type.
          ARRAY            # Array type.
          OBJECT           # Object type.
        end
      end

      # A predicted `FunctionCall` returned from the model that contains a string
      # representing the `FunctionDeclaration#name` with the arguments and their
      # values.
      struct FunctionCall
        include JSON::Serializable
        # _Required_. The name of the function to call.
        getter name : String
        # _Optional_. The function parameters and values in JSON object format.
        getter args : JSON::Any?

        def to_json_object_key
          "functionCall"
        end
      end

      # This should contain the result of a `FunctionCall` made based on model
      # prediction.
      #
      # See: https://ai.google.dev/api/caching#FunctionResponse
      struct FunctionResponse
        include JSON::Serializable
        # _Required_. The name of the function to call.
        property name : String
        # _Required_. The function response in JSON object format.
        property response : JSON::Any

        def initialize(@name, @response)
        end

        def to_json_object_key
          "functionResponse"
        end
      end

      # `Part` inline text data type
      alias Text = String

      # The Tool configuration containing parameters for specifying Tool use in the request.
      #
      # See: https://ai.google.dev/api/caching#ToolConfig
      struct ToolConfig
        include JSON::Serializable
        # _Optional_. Function calling config.
        @[JSON::Field(key: "functionCallingConfig")]
        property function_calling_config : FunctionCallingConfig?
      end

      struct FunctionCallingConfig
        include JSON::Serializable
        # _Optional_. Specifies the mode in which function calling should execute.
        property mode : Mode?

        # _Optional_. A set of function names that, when provided, limits the
        # functions the model will call.
        @[JSON::Field(key: "allowedFunctionNames")]
        property allowed_function_names : Array(String)?

        # Defines the execution behavior for function calling by defining the execution mode.
        #
        # See: https://ai.google.dev/api/caching#Mode
        enum Mode
          MODE_UNSPECIFIED # Unspecified function calling mode. This value should not be used.
          AUTO             # Default model behavior, model decides to predict either a function call or a natural language response.
          ANY              # Model is constrained to always predicting a function call only. If "allowedFunctionNames" are set, the predicted function call will be limited to any one of "allowedFunctionNames", else the predicted function call will be any one of the provided "functionDeclarations".
          NONE             # Model will not predict any function call. Model behavior is same as when not passing any function declarations.
        end
      end

      # Defines the reason why the model stopped generating tokens.
      #
      # See: https://ai.google.dev/api/generate-content#FinishReason
      enum FinishReason
        FINISH_REASON_UNSPECIFIED # Default value. This value is unused.
        STOP                      # Natural stop point of the model or provided stop sequence.
        MAX_TOKENS                # The maximum number of tokens as specified in the request was reached.
        SAFETY                    # The response candidate content was flagged for safety reasons.
        RECITATION                # The response candidate content was flagged for recitation reasons.
        LANGUAGE                  # The response candidate content was flagged for using an unsupported language.
        OTHER                     # Unknown reason.
        BLOCKLIST                 # Token generation stopped because the content contains forbidden terms.
        PROHIBITED_CONTENT        # Token generation stopped for potentially containing prohibited content.
        SPII                      # Token generation stopped because the content potentially contains Sensitive Personally Identifiable Information (SPII).
        MALFORMED_FUNCTION_CALL   # The function call generated by the model is invalid.
      end

      # A datatype containing media that is part of a multi-part `Content` message.
      #
      # Union field `data`. `data` can be only one of the following:
      #
      # * __text__: string - Inline text.
      # * __inlineData__: object (Blob) - Inline media bytes.
      # * __functionCall__: object (FunctionCall) - A predicted FunctionCall returned
      #   from the model that contains a string representing the
      #   `FunctionDeclaration#name` with the arguments and their values.
      # * __functionResponse__: object (FunctionResponse) - The result output of a
      #   `FunctionCall` that contains a string representing the
      #   `FunctionDeclaration#name` and a structured JSON object containing any
      #   output from the function is used as context to the model.
      # * __fileData__: object (FileData) - URI based data.
      # * __executableCode__: object (ExecutableCode) - Code generated by the model that
      #   is meant to be executed.
      # * __codeExecutionResult__: object (CodeExecutionResult) - Result of executing
      #   the ExecutableCode.
      #
      # See: https://ai.google.dev/api/caching#Part
      struct Part
        def initialize(@data)
        end

        macro one_of(name)
          def {{name.var.id}} : {{name.type}}
            @{{name.var.id}}
          end

          def {{name.var.id}}=(@{{name.var.id}} : {{name.type}})
          end

          {% for type in name.type.types.map(&.stringify) %}
            {% field = type.underscore %}

            # if `#data` type is `{{ type.id }}` will return value, or nil if not
            def {{field.id}}?
              data.as({{type.id}}) if data.is_a?({{type.id}})
            end

            # Do not yield if `#data` is a diferent type
            def {{field.id}}?(&)
              value = {{field.id}}?

              return if value.nil?
              yield value
            end

            # Same as `#{{ field.id }}?` but raise error if nil
            def {{field.id}}!
              {{field.id}}?.not_nil!
            end
          {% end %}

          # Custom JSON deserializable
          def initialize(pull : JSON::PullParser)
            pull.read_begin_object
            {% begin %}
              case key = pull.read_object_key
              {% for type in name.type.types.map(&.stringify) %}
                when {{type.camelcase(lower: true)}}
                {% if type.downcase == "text" %}
                  @data = pull.read_string.rstrip
                {% else %}
                  @data = {{type.id}}.from_json(pull.read_raw)
                {% end %}
              {% end %}
              else
                raise "eloquent -- Undefined #{self.class} JSON field: #{key}"
              end
            {% end %}
            pull.read_end_object
          end
        end

        # Custom JSON serializable
        def to_json(json : JSON::Builder)
          json.object do
            if text = text?
              json.field "text", text
            else
              json.field data.to_json_object_key do
                data.to_json(json)
              end
            end
          end
        end

        # one of type
        one_of data : (Text | FunctionCall | FunctionResponse)
      end

      # The base structured datatype containing multi-part content of a message.
      #
      # See: https://ai.google.dev/api/caching#Content
      struct Content
        include JSON::Serializable
        # _Optional_. The producer of the content.
        property role : Role?
        # Ordered Parts that constitute a single message.
        # Parts may have different MIME types.
        property parts : Array(Part)

        # Create using existing parts or new empty array
        def initialize(@parts = [] of Part, @role = nil)
        end

        # Create content with a single part
        def initialize(part : Part, @role = nil)
          @parts = [part]
        end

        # Create content with a text part already
        def initialize(text : String, @role = nil)
          initialize(Part.new(text), @role)
        end

        # Remove empty texts `Part` from JSON to fix: "Unable to submit request because it has an empty text parameter."
        def after_initialize
          @parts.select! do |part|
            !(part.text? && part.text? &.empty?)
          end
        end

        # Markdown special character escaping
        def escape_md
          Helpers.escape_md to_s
        end

        def to_s
          io = IO::Memory.new

          parts.each &.text? do |text|
            io << text << '\n'
          end

          io.to_s
        end

        enum Role
          User
          Model
          Function
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

    # Simplified error response
    struct Error
      include JSON::Serializable
      getter code : Int32
      getter message : String
      getter status : String
    end
  end
end
