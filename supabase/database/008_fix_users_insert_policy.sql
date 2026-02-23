-- Fix users table INSERT policy to allow authenticated users
-- This fixes the issue where Kakao login fails with "row violates row-level security policy"

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON users;

-- Recreate INSERT policy with TO authenticated clause
CREATE POLICY "Users can insert own profile" ON users
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Note: The TO authenticated clause ensures that only authenticated users
-- can insert records, which is required for social login (Kakao, Google, etc.)
