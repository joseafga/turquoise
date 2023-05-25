-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  first_name VARCHAR NOT NULL,
  last_name VARCHAR,
  username VARCHAR,
  language_code VARCHAR,
  is_bot BOOLEAN NOT NULL,

  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE users;
