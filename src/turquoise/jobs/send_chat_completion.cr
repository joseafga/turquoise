module Turquoise
  module Jobs
    class SendChatCompletion < Mosquito::QueuedJob
      include Mosquito::RateLimiter
      @reply_to_message_id : Int64? = nil

      param chat_id : Int64
      param text : String
      param message_id : Int64
      param from_name : String = ""
      throttle limit: 6, per: 1.minute

      def perform
        eloquent = Eloquent.new(chat_id)
        act_as_group if eloquent.chat.type != "private"
        message = eloquent.generate(text)
        options = {chat_id: chat_id, reply_to_message_id: @reply_to_message_id}
        return if message.nil? # no message to send

        if photo = message.photo
          return Bot.send_photo **options.merge({photo: photo, caption: message.escape_md})
        end

        Bot.send_message **options.merge({text: message.escape_md})
      end

      def reschedule_interval(retry_count)
        30.seconds * retry_count
      end

      # Add more information when in group chats
      def act_as_group
        @text = "#{from_name} say: #{text}" unless from_name.empty?
        @reply_to_message_id = message_id
      end
    end
  end
end
