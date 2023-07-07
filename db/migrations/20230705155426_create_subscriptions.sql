-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE subscriptions (
  topic VARCHAR PRIMARY KEY,
  secret VARCHAR,
  is_active BOOLEAN NOT NULL,

  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE subscriptions;