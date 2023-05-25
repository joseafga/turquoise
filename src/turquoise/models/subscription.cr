class Subscription < Granite::Base
  table subscriptions

  belongs_to :user
  belongs_to :chat

  column id : Int64, primary: true
  column topic : String?
  column is_active : Bool = true

  timestamps
end
