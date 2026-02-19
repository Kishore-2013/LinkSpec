-- ============================================================================
-- FIX: Infinite Recursion in RLS Policies
-- ============================================================================
-- This script fixes the "Infinite recursion detected in policy" error
-- Run this in Supabase SQL Editor BEFORE running the full schema
-- ============================================================================

-- Drop existing policies that cause infinite recursion
DROP POLICY IF EXISTS "Users can view profiles in same domain" ON profiles;
DROP POLICY IF EXISTS "Users can view posts in same domain" ON posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON posts;

-- Create helper function to get user's domain (SECURITY DEFINER bypasses RLS)
CREATE OR REPLACE FUNCTION get_user_domain(user_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT domain_id FROM profiles WHERE id = user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate profiles SELECT policy (fixed)
CREATE POLICY "Users can view profiles in same domain"
  ON profiles
  FOR SELECT
  USING (
    auth.uid() = id  -- Can always see own profile
    OR 
    domain_id = get_user_domain(auth.uid())  -- Or profiles in same domain
  );

-- Recreate posts SELECT policy (fixed)
CREATE POLICY "Users can view posts in same domain"
  ON posts
  FOR SELECT
  USING (
    domain_id = get_user_domain(auth.uid())
  );

-- Recreate posts INSERT policy (fixed)
CREATE POLICY "Users can insert own posts"
  ON posts
  FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    domain_id = get_user_domain(auth.uid())
  );

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Run this to verify the policies are fixed:
-- SELECT * FROM profiles WHERE id = auth.uid();
-- ============================================================================
