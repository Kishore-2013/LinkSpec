-- Run this in Supabase SQL Editor
-- Step 1: See ALL current policies on the posts table
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'posts';
