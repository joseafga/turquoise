-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE INDEX topic_chat_active_idx ON subscriptions (topic, chat_id, is_active);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP INDEX topic_chat_active_idx;
