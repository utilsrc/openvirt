CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username TEXT UNIQUE,
  balance NUMERIC(10,2)
);

CREATE TABLE devices (
  id SERIAL PRIMARY KEY,
  type TEXT CHECK (type IN ('CPU', 'GPU')),
  model TEXT,
  config JSONB,
  is_available BOOLEAN DEFAULT TRUE
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  device_id INTEGER REFERENCES devices(id),
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  price_per_hour NUMERIC(10,2),
  total_cost NUMERIC(10,2)
);
