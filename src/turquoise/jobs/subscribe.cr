module Turquoise
  module Jobs
    class Subscribe < Mosquito::QueuedJob
      param message_id : Int64
      param user_id : Int64
      param chat_id : Int64
      param topic : String

      def perform
        if Models::Listener.exists? chat_id: chat_id, subscription_topic: topic
          raise "O grupo já está inscrito neste canal."
        end

        if subscription = Models::Subscription.find(topic)
          subscription.subscribe unless subscription.active?
        else
          Models::Subscription.create! topic: topic
        end

        Models::Listener.create! user_id: user_id, chat_id: chat_id, subscription_topic: topic
        reply("Inscrito com sucesso. 🫡")
      rescue ex : Granite::RecordNotSaved
        message = String.build do |msg|
          msg << "Ocorreram os seguintes erros:"

          ex.model.errors.each do |error|
            msg << "\n- #{error.message}"
          end
        end

        reply(Helpers.escape_md message)
      rescue ex
        message = "Erro ao inscrever-se: #{ex.message || ex.cause.try &.message}"
        reply(Helpers.escape_md message)
      end

      def reply(text)
        Bot.send_message(chat_id: chat_id, text: text, reply_to_message_id: message_id)
      end
    end
  end
end
