module Turquoise
  module Jobs
    class SendChatCompletion < Mosquito::QueuedJob
      include Mosquito::RateLimiter

      param chat_id : Int64
      param text : String
      param message_id : Int64
      throttle limit: 3, per: 1.minute

      def perform
        eloquent = Eloquent.new(chat_id)
        reply = eloquent.completion(text)
        options = {chat_id: chat_id, reply_to_message_id: message_id}
        options = options.merge({reply_to_message_id: nil}) if message_id.zero? || eloquent.chat.type == "private"

        if photo = reply.photo
          Bot.send_photo **options.merge({photo: photo, caption: reply.escape_md})
          return
        end

        Bot.send_message **options.merge({text: reply.escape_md})
      end

      def reschedule_interval(retry_count)
        20.seconds * retry_count
      end
    end
  end
end
