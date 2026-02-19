-- ============================================================================
-- EMERGENCY FIX: Domain-Gating Not Working
-- ============================================================================
-- This script will fix the domain-gating issue
-- Run this in Supabase SQL Editor NOW
-- ============================================================================

-- Step 1: Check current state
SELECT 
  p.id,
  p.content,
  p.domain_id as post_domain,
  p.author_id,
  pr.full_name,
  pr.domain_id as author_domain
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id;

-- If post_domain is NULL or doesn't match author_domain, the trigger isn't working!

-- ============================================================================

-- Step 2: Fix existing posts (set domain_id based on author's profile)
UPDATE posts
SET domain_id = (
  SELECT domain_id 
  FROM profiles 
  WHERE profiles.id = posts.author_id
)
WHERE domain_id IS NULL 
   OR domain_id != (SELECT domain_id FROM profiles WHERE profiles.id = posts.author_id);

-- ============================================================================

-- Step 3: Verify the fix
SELECT 
  p.id,
  p.content,
  p.domain_id as post_domain,
  pr.full_name,
  pr.domain_id as author_domain,
  CASE 
    WHEN p.domain_id = pr.domain_id THEN '✅ CORRECT'
    ELSE '❌ WRONG'
  END as status
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id;

-- All should show ✅ CORRECT

-- ============================================================================

-- Step 4: Test RLS by checking what YOU can see
-- This should only show posts in YOUR domain
SELECT * FROM posts;

-- ============================================================================

-- Step 5: If RLS is not working, check if it's enabled
SELECT 
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname = 'public' 
  AND tablename IN ('profiles', 'posts', 'likes', 'connections');

-- rowsecurity should be 't' (true) for all tables

-- ============================================================================

-- Step 6: If rowsecurity is false, enable it
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;

-- ============================================================================

-- Step 7: Verify RLS policies exist
SELECT 
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'posts';

-- Should see:
-- - "Users can view posts in same domain" (SELECT)
-- - "Users can insert own posts" (INSERT)
-- - "Users can update own posts" (UPDATE)
-- - "Users can delete own posts" (DELETE)

-- ============================================================================

-- Step 8: If policies are missing, recreate them
DROP POLICY IF EXISTS "Users can view posts in same domain" ON posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
DROP POLICY IF EXISTS "Users can update own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON posts;

-- Recreate SELECT policy
CREATE POLICY "Users can view posts in same domain"
  ON posts
  FOR SELECT
  USING (
    domain_id = get_user_domain(auth.uid())
  );

-- Recreate INSERT policy
CREATE POLICY "Users can insert own posts"
  ON posts
  FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    domain_id = get_user_domain(auth.uid())
  );

-- Recreate UPDATE policy
CREATE POLICY "Users can update own posts"
  ON posts
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Recreate DELETE policy
CREATE POLICY "Users can delete own posts"
  ON posts
  FOR DELETE
  USING (auth.uid() = author_id);

-- ============================================================================

-- Step 9: Final test - you should only see posts in your domain
SELECT 
  p.*,
  pr.full_name as author,
  pr.domain_id as author_domain,
  get_user_domain(auth.uid()) as my_domain
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id;

-- The query should only return posts where author_domain = my_domain

-- ============================================================================

-- Step 10: Test from the app
-- After running this script:
-- 1. Refresh your browser
-- 2. Sign in as IT/Software user
-- 3. You should NOT see Medical posts
-- 4. Sign in as Medical user
-- 5. You SHOULD see Medical posts

-- ============================================================================
