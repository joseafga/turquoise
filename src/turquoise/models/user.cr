module Turquoise
  module Models
    class User < Granite::Base
      table users

      has_many :subscriptions, class_name: Subscription

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
