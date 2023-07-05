-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE subscriptions (
  id BIGSERIAL PRIMARY KEY,
  topic VARCHAR NOT NULL,
  is_active BOOLEAN NOT NULL,

  user_id BIGSERIAL,
  chat_id BIGSERIAL,

  created_at TIMESTAMP,
  updated_at TIMESTAMP,

  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(chat_id) REFERENCES chats(id)
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE subscriptions;