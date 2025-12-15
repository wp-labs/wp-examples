CREATE TABLE IF NOT EXISTS {table} (
  id INTEGER PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_{table}_value ON {table}(value);
