ALTER TABLE sets ADD COLUMN IF NOT EXISTS abbreviation text;

CREATE INDEX IF NOT EXISTS idx_sets_abbreviation ON sets (UPPER(abbreviation));
