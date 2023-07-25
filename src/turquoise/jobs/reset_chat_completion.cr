module Turquoise
  module Jobs
    class ResetChatCompletion < Mosquito::QueuedJob
      param chat_id : Int64

      def perform
        Eloquent.new(chat_id).clear

        Bot.send_message chat_id: chat_id, text: "O histórico de conversa foi limpo com sucesso."
      end
    end
  end
end
