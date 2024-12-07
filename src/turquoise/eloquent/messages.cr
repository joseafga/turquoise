module Turquoise
  class Eloquent
    struct Messages
      getter? active = false
      property current = [] of Gemini::Content
      property future = [] of Gemini::Content

      def initialize(@key : String)
      end

      def transaction
        @active = true
      end

      def rollback
        future.clear
        @active = false
      end

      def commit
        unless active? # Cancelled
          Log.warn { "eloquent -- Attempt to commit without active transaction" }
          return
        end

        current.concat future
        Redis.rpush @key, future.map(&.to_json)
        Redis.ltrim @key, -MAX_MESSAGES, -1
        future.clear
        @active = false
      end

      def transaction(&)
        transaction
        yield
        commit
      end

      def value
        current + future
      end

      def push(message)
        unless active? # Cancelled
          Log.warn { "eloquent -- Cannot push without active transaction" }
          return
        end

        future.push message
      end

      # Alias to `#push`
      def <<(message)
        push(message)
      end

      # Load messages from persistent memory to volatile memory
      def load
        Redis.lrange(@key, 0, -1).each do |message|
          current << Gemini::Content.from_json message.as(String)
        end
        self
      end

      # Remove messages from volatile memory
      def clear
        future.clear
        current.clear
        self
      end

      # Remove messages from persistent memory
      def delete
        Redis.del @key
        self
      end
    end
  end
end
