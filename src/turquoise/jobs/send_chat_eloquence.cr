module Turquoise
  module Jobs
    class SendChatEloquence < Mosquito::QueuedJob
      include Mosquito::RateLimiter
      @eloquent : Eloquent?

      param chat_id : Int64
      param text : String
      param message_id : Int64
      throttle limit: 6, per: 1.minute

      def perform
        options = {chat_id: chat_id, reply_to_message_id: message_id_or_nil}
        eloquent = Eloquent.new(chat_id)

        eloquent.messages.transaction do
          response = eloquent.generate(text)
          text = Helpers.escape_md(response)

          if eloquent.media.present?
            # Merge response as caption if caption no exists
            unless eloquent.media_captions?
              eloquent.media.first.caption = text
              text = ""
            end

            if eloquent.media.size == 1
              File.open(eloquent.media.first.media) do |file|
                Bot.send_photo **options, photo: file, caption: eloquent.media.first.caption
              end
            elsif eloquent.media.size > 1
              Bot.send_media_group **options, media: eloquent.media
            end
          end

          next if text.empty?
          Bot.send_message **options, text: text
        end
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
