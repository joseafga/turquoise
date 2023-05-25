-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE chats (
  id BIGSERIAL PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT,
  username TEXT,
  first_name TEXT,
  last_name TEXT,
  description TEXT,
  is_forum BOOLEAN NOT NULL,

  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE chats;
