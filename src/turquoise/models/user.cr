module Turquoise
  module Models
    class User < Granite::Base
      table users

      has_many listening : Listener
      has_many subscriptions : Subscription, through: :listeners, primary_key: :subscription_topic

      column id : Int64, primary: true, auto: false
      column first_name : String
      column last_name : String?
      column username : String?
      column language_code : String?
      column is_bot : Bool = false
      timestamps
    end
  end
end
