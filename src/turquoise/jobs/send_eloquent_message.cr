module Turquoise
  module Jobs
    class SendEloquentMessage < Mosquito::QueuedJob
      param message_id : Int64
      param chat_id : Int64
      param text : String

      def perform
        reply = Eloquent.instance(chat_id).message(text)

        if message_id.zero?
          Bot.send_message chat_id: chat_id, text: Helpers.escape_md(reply)
        else
          Bot.send_message chat_id: chat_id, text: Helpers.escape_md(reply), reply_to_message_id: message_id
        end
      end

      def reschedule_interval(retry_count)
        20.seconds * (retry_count ** 2)
      end
    end
  end
end
