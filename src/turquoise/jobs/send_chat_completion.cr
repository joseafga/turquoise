module Turquoise
  module Jobs
    class SendChatCompletion < Mosquito::QueuedJob
      include Mosquito::RateLimiter
      @eloquent : Eloquent?

      param chat_id : Int64
      param text : String
      param message_id : Int64
      throttle limit: 6, per: 1.minute

      def perform
        @eloquent = Eloquent.new(chat_id)

        if eloquent = @eloquent
          content = eloquent.generate(text)
          options = {chat_id: chat_id, reply_to_message_id: message_id_or_nil}

          return if content.nil? # no message to send
          text = content.escape_md

          if eloquent.media.present?
            # Merge response as caption if caption no exists
            unless eloquent.media_captions?
              eloquent.media.first.caption = text
              text = ""
            end

            if eloquent.media.size == 1
              File.open(eloquent.media.first.media) do |file|
                Bot.send_photo **options.merge({photo: file, caption: eloquent.media.first.caption})
              end
            elsif eloquent.media.size > 1
              Bot.send_media_group **options.merge({media: eloquent.media})
            end
          end

          return if text.empty?
          Bot.send_message **options.merge({text: text})
        end
      end

      after do
        @eloquent.try(&.save!) if succeeded?
      end

      def reschedule_interval(retry_count)
        30.seconds * retry_count
      end

      def message_id_or_nil : Int64?
        message_id.zero? ? nil : message_id
      end
    end
  end
end
