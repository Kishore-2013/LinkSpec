-- ============================================================================
-- DEBUG: Check Domain-Gating Implementation
-- ============================================================================
-- Run these queries in Supabase SQL Editor to debug the issue
-- ============================================================================

-- 1. Check if posts have domain_id set correctly
SELECT 
  p.id,
  p.content,
  p.domain_id as post_domain,
  pr.full_name as author_name,
  pr.domain_id as author_domain
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
ORDER BY p.created_at DESC;

-- Expected: post_domain should match author_domain

-- ============================================================================

-- 2. Check all profiles and their domains
SELECT 
  id,
  full_name,
  domain_id,
  created_at
FROM profiles
ORDER BY created_at DESC;

-- Expected: Each user should have a domain_id

-- ============================================================================

-- 3. Check if RLS policies exist
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('profiles', 'posts')
ORDER BY tablename, policyname;

-- Expected: Should see policies for SELECT, INSERT, UPDATE, DELETE

-- ============================================================================

-- 4. Check if get_user_domain function exists
SELECT 
  proname as function_name,
  prosrc as function_body
FROM pg_proc
WHERE proname = 'get_user_domain';

-- Expected: Should return the function

-- ============================================================================

-- 5. Test the RLS policy manually
-- Replace <your-user-id> with your actual user ID
SELECT 
  p.*,
  pr.domain_id as author_domain,
  (SELECT domain_id FROM profiles WHERE id = auth.uid()) as my_domain
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
WHERE p.domain_id = (SELECT domain_id FROM profiles WHERE id = auth.uid());

-- Expected: Should only return posts matching your domain

-- ============================================================================

-- 6. Check if the trigger function exists
SELECT 
  proname as function_name,
  prosrc as function_body
FROM pg_proc
WHERE proname = 'set_post_domain';

-- Expected: Should return the trigger function

-- ============================================================================

-- 7. Check if the trigger is attached to posts table
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'posts'::regclass;

-- Expected: Should see trigger_set_post_domain

-- ============================================================================
