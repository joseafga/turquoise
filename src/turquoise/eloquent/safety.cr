module Turquoise
  class Eloquent
    module Chat
      # The category of a rating.
      #
      # See: https://ai.google.dev/api/generate-content#harmcategory
      enum HarmCategory
        HARM_CATEGORY_UNSPECIFIED       # Category is unspecified.
        HARM_CATEGORY_DEROGATORY        # PaLM - Negative or harmful comments targeting identity and/or protected attribute.
        HARM_CATEGORY_TOXICITY          # PaLM - Content that is rude, disrespectful, or profane.
        HARM_CATEGORY_VIOLENCE          # PaLM - Describes scenarios depicting violence against an individual or group, or general descriptions of gore.
        HARM_CATEGORY_SEXUAL            # PaLM - Contains references to sexual acts or other lewd content.
        HARM_CATEGORY_MEDICAL           # PaLM - Promotes unchecked medical advice.
        HARM_CATEGORY_DANGEROUS         # PaLM - Dangerous content that promotes, facilitates, or encourages harmful acts.
        HARM_CATEGORY_HARASSMENT        # Gemini - Harassment content.
        HARM_CATEGORY_HATE_SPEECH       # Gemini - Hate speech and content.
        HARM_CATEGORY_SEXUALLY_EXPLICIT # Gemini - Sexually explicit content.
        HARM_CATEGORY_DANGEROUS_CONTENT # Gemini - Dangerous content.
        HARM_CATEGORY_CIVIC_INTEGRITY   # Gemini - Content that may be used to harm civic integrity.
      end

      # Block at and beyond a specified harm probability.
      #
      # See: https://ai.google.dev/api/generate-content#HarmBlockThreshold
      enum HarmBlockThreshold
        HARM_BLOCK_THRESHOLD_UNSPECIFIED # Threshold is unspecified.
        BLOCK_LOW_AND_ABOVE              # Content with NEGLIGIBLE will be allowed.
        BLOCK_MEDIUM_AND_ABOVE           # Content with NEGLIGIBLE and LOW will be allowed.
        BLOCK_ONLY_HIGH                  # Content with NEGLIGIBLE, LOW, and MEDIUM will be allowed.
        BLOCK_NONE                       # All content will be allowed.
        OFF                              # Turn off the safety filter.
      end

      # The probability that a piece of content is harmful.
      #
      # See: https://ai.google.dev/api/generate-content#HarmProbability
      enum HarmProbability
        HARM_PROBABILITY_UNSPECIFIED # Probability is unspecified.
        NEGLIGIBLE                   # Content has a negligible chance of being unsafe.
        LOW                          # Content has a low chance of being unsafe.
        MEDIUM                       # Content has a medium chance of being unsafe.
        HIGH                         # Content has a high chance of being unsafe.
      end

      # Specifies the reason why the prompt was blocked.
      #
      # See: https://ai.google.dev/api/generate-content#BlockReason
      enum BlockReason
        BLOCK_REASON_UNSPECIFIED # Default value. This value is unused.
        SAFETY                   # Prompt was blocked due to safety reasons. Inspect safetyRatings to understand which safety category blocked it.
        OTHER                    # Prompt was blocked due to unknown reasons.
        BLOCKLIST                # Prompt was blocked due to the terms which are included from the terminology blocklist.
        PROHIBITED_CONTENT       # Prompt was blocked due to prohibited content.
      end

      # Safety rating for a piece of content.
      #
      # See: https://ai.google.dev/api/generate-content#safetyrating
      struct SafetyRating
        include JSON::Serializable
        getter category : HarmCategory
        getter probability : HarmProbability
        getter? blocked = false

        def initialize(@category, @probability)
        end
      end

      # Safety setting, affecting the safety-blocking behavior.
      #
      # See: https://ai.google.dev/api/generate-content#safetysetting
      struct SafetySetting
        include JSON::Serializable
        getter category : HarmCategory
        getter threshold : HarmBlockThreshold

        def initialize(@category, @threshold)
        end
      end
    end
  end
end
