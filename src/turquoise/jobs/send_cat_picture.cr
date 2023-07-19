module Turquoise
  module Jobs
    class SendCatPicture < Mosquito::QueuedJob
      param chat_id : Int64

      # Send a random static (jpg or png) or animated (gif) picture.
      def perform
        format = ["gif", "jpg", "png"].sample
        url = Pets::Cat.random mime_types: format, time: Time.utc.to_unix.to_s

        if format == "gif"
          Bot.send_animation animation: url, chat_id: chat_id
        else
          Bot.send_photo photo: url, chat_id: chat_id
        end
      end
    end
  end
end
