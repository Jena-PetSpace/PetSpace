-- Update pets table to match Flutter app schema

-- Add missing columns
ALTER TABLE pets
ADD COLUMN IF NOT EXISTS birth_date DATE,
ADD COLUMN IF NOT EXISTS avatar_url TEXT,
ADD COLUMN IF NOT EXISTS description TEXT,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Rename columns to match Flutter app
ALTER TABLE pets RENAME COLUMN owner_id TO user_id;
ALTER TABLE pets RENAME COLUMN species TO type;
ALTER TABLE pets RENAME COLUMN photo_url TO temp_photo_url;

-- Drop age column as we're using birth_date instead
ALTER TABLE pets DROP COLUMN IF EXISTS age;

-- Use avatar_url instead of photo_url
UPDATE pets SET avatar_url = temp_photo_url WHERE temp_photo_url IS NOT NULL;
ALTER TABLE pets DROP COLUMN IF EXISTS temp_photo_url;

-- Add trigger for updated_at
CREATE TRIGGER update_pets_updated_at BEFORE UPDATE ON pets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Update index
DROP INDEX IF EXISTS idx_pets_owner_id;
CREATE INDEX idx_pets_user_id ON pets(user_id);
