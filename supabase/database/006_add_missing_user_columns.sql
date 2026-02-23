-- Add missing columns to users table for onboarding and social features
-- Migration: 006_add_missing_user_columns.sql

-- Add is_onboarding_completed column
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_onboarding_completed BOOLEAN DEFAULT FALSE;

-- Add pets array column (stores pet IDs)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS pets UUID[] DEFAULT ARRAY[]::UUID[];

-- Add following array column (stores user IDs being followed)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS following UUID[] DEFAULT ARRAY[]::UUID[];

-- Add followers array column (stores follower user IDs)
ALTER TABLE users
ADD COLUMN IF NOT EXISTS followers UUID[] DEFAULT ARRAY[]::UUID[];

-- Create indexes for array columns for better query performance
CREATE INDEX IF NOT EXISTS idx_users_pets ON users USING GIN(pets);
CREATE INDEX IF NOT EXISTS idx_users_following ON users USING GIN(following);
CREATE INDEX IF NOT EXISTS idx_users_followers ON users USING GIN(followers);
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users(is_onboarding_completed);

-- Comment the columns for documentation
COMMENT ON COLUMN users.is_onboarding_completed IS 'Whether the user has completed the onboarding process';
COMMENT ON COLUMN users.pets IS 'Array of pet UUIDs owned by this user';
COMMENT ON COLUMN users.following IS 'Array of user UUIDs that this user follows';
COMMENT ON COLUMN users.followers IS 'Array of user UUIDs that follow this user';
