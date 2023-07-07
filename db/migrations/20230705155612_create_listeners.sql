-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE listeners (
  id BIGSERIAL PRIMARY KEY,

  user_id BIGSERIAL,
  chat_id BIGSERIAL,
  subscription_topic VARCHAR,

  created_at TIMESTAMP,
  updated_at TIMESTAMP,

  FOREIGN KEY(user_id) REFERENCES users(id),
  FOREIGN KEY(chat_id) REFERENCES chats(id),
  FOREIGN KEY(subscription_topic) REFERENCES subscriptions(topic)
);

CREATE INDEX user_id_idx ON listeners (user_id);
CREATE INDEX chat_id_idx ON listeners (chat_id);
CREATE INDEX subscription_topic_idx ON listeners (subscription_topic);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX user_id_idx;
DROP INDEX chat_id_idx;
DROP INDEX subscription_topic_idx;
DROP TABLE listeners;