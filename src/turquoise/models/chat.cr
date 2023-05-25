class Chat < Granite::Base
  table chats

  has_many :messages, class_name: Message

  column id : Int64, primary: true
  column type : String
  column title : String?
  column username : String?
  column first_name : String?
  column last_name : String?
  column description : String?
  column is_forum : Bool = false

  timestamps
end
