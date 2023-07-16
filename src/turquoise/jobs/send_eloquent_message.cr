module Turquoise
  module Jobs
    class SendEloquentMessage < Mosquito::QueuedJob
      param chat_id : Int64
      param text : String
      param message_id : Int64

      def perform
        eloquent = Eloquent.instance(chat_id)
        response = eloquent.message(text)
        options = {chat_id: chat_id, reply_to_message_id: message_id}
        options = options.merge({reply_to_message_id: nil}) if message_id.zero? || eloquent.chat.type == "private"

        if response.matches? Regex.new(ENV["ELOQUENT_PICTURE_KEYWORD"])
          if photo = picture_file
            Bot.send_photo **options.merge({photo: photo, caption: Helpers.escape_md(response)})
          end
          return
        end

        Bot.send_message **options.merge({text: Helpers.escape_md(response)})
      end

      def reschedule_interval(retry_count)
        20.seconds * retry_count
      end

      def picture_file
        dir = ::File.expand_path("../../../img/pictures/", __DIR__)
        picture = ::Dir.glob(::File.join(dir, "/turquesa_*.jpg")).sample

        return ::File.open(picture, "rb") if ::File.exists? picture
        nil
      end
    end
  end
end
