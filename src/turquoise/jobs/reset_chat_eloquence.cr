module Turquoise
  module Jobs
    class ResetChatEloquence < Mosquito::QueuedJob
      param chat_id : Int64

      def perform
        Eloquent.new(chat_id).messages.clear.delete

        Bot.send_message chat_id: chat_id, text: "O histórico de conversa foi limpo com sucesso."
      end
    end
  end
end
