module Turquoise
  module Models
    class Chat < Granite::Base
      table chats

      has_many listening : Listener
      has_many subscriptions : Subscription, through: :listeners, primary_key: :subscription_topic

      column id : Int64, primary: true, auto: false
      column type : String
      column title : String?
      column username : String?
      column first_name : String?
      column last_name : String?
      column description : String?
      column is_forum : Bool = false
      timestamps
    end
  end
end
