module Turquoise
  module Jobs
    class RenewSubscription < Mosquito::QueuedJob
      param topic : String

      def perform
        # unsubscribed before renew
        fail "A inscrição está inativa." unless subscription.active?

        subscription.subscribe
      end

      def subscription : Models::Subscription
        if subscription = Models::Subscription.find(topic)
          return subscription
        end
        fail "Inscrição não encontrada."
      end
    end
  end
end
