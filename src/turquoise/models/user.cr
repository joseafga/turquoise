class User < Granite::Base
  table users

  has_many :messages, class_name: Message

  column id : Int64, primary: true
  column first_name : String
  column last_name : String?
  column username : String?
  column language_code : String?
  column is_bot : Bool = false

  timestamps
end
