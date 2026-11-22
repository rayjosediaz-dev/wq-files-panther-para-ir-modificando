CREATE TABLE IF NOT EXISTS license_keys (key TEXT PRIMARY KEY, device TEXT, activated_at TEXT);
CREATE TABLE IF NOT EXISTS patches (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', enabled INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, expires_at INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS idx_keys_activation ON license_keys(activated_at);
