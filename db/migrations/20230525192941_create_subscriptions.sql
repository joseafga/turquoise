-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE subscriptions (
  id BIGSERIAL PRIMARY KEY,
  topic VARCHAR,
  is_active BOOLEAN NOT NULL,

  user_id BIGSERIAL,
  chat_id BIGSERIAL,

  created_at TIMESTAMP,
  updated_at TIMESTAMP,

  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(chat_id) REFERENCES chats(id)
);

CREATE INDEX user_id_idx ON subscriptions (user_id);
CREATE INDEX chat_id_idx ON subscriptions (chat_id);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX user_id_idx;
DROP INDEX chat_id_idx;
DROP TABLE subscriptions;