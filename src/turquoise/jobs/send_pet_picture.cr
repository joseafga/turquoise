module Turquoise
  module Jobs
    class SendPetPicture < Mosquito::QueuedJob
      param api_url : String
      param chat_id : Int64

      # Send a random static (jpg or png) or animated (gif) picture.
      def perform
        if ::File.extname(url = fetch_url) == ".gif"
          Bot.send_animation animation: url, chat_id: chat_id
        else # .jpg, .png
          Bot.send_photo photo: url, chat_id: chat_id
        end
      end

      # Fetch image URL from API
      def fetch_url
        response = HTTP::Client.get api_url
        data = Array(Hash(String, String | UInt16)).from_json(response.body)
        data.first["url"].to_s
      end
    end
  end
end
