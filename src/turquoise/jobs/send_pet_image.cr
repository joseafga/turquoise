module Turquoise
  module Jobs
    class SendPetImage < Mosquito::QueuedJob
      param pet : String
      param chat_id : Int64

      # Send a random static (jpg or png) or animated (gif) image.
      def perform
        format = ["gif", "jpg", "png"].sample
        image = Pets::Images.parse(pet).random(mime_types: format)

        if format == "gif"
          Bot.send_animation animation: image.url, chat_id: chat_id
        else
          Bot.send_photo photo: image.url, chat_id: chat_id
        end
      end
    end
  end
end
