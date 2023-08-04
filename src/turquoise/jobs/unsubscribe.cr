module Turquoise
  module Jobs
    class Unsubscribe < Mosquito::QueuedJob
      param message_id : Int64
      param chat_id : Int64
      param topic : String

      def perform
        if listener = Models::Listener.find_by chat_id: chat_id, subscription_topic: topic
          listener.destroy!
        else
          raise "Não existe inscrição ativa para este canal."
        end

        reply("Desinscrito com sucesso... 🥹")
      rescue ex
        message = "Erro ao desinscrever-se: #{ex.message || ex.cause.try &.message}"
        reply(Helpers.escape_md message)
      end

      def reply(text)
        Bot.send_message chat_id: chat_id, text: text, reply_to_message_id: message_id
      end
    end
  end
end
