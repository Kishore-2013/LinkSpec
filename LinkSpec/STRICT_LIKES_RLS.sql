-- ============================================================================
-- SECURITY FIX: Strengthening Liked Post Domain Isolation
-- ============================================================================
-- This script ensures that users cannot like posts from other domains, 
-- even if they manage to see the post through a shared link.
-- ============================================================================

-- Step 1: Drop existing like policies
DROP POLICY IF EXISTS "Users can view likes in same domain" ON likes;
DROP POLICY IF EXISTS "Users can like posts in same domain" ON likes;

-- Step 2: Create a stricter SELECT policy for likes
CREATE POLICY "Users can view likes in same domain"
  ON likes
  FOR SELECT
  USING (
    -- User can only see likes for posts that belong to their domain
    post_id IN (
      SELECT id FROM posts 
      WHERE domain_id IN (
        SELECT domain_id FROM profiles WHERE id = auth.uid()
      )
    )
  );

-- Step 3: Create a stricter INSERT policy for likes
CREATE POLICY "Users can like posts in same domain"
  ON likes
  FOR INSERT
  WITH CHECK (
    -- 1. User must be liking as themselves
    auth.uid() = user_id 
    AND 
    -- 2. The post must belong to their own domain
    post_id IN (
      SELECT id FROM posts 
      WHERE domain_id IN (
        SELECT domain_id FROM profiles WHERE id = auth.uid()
      )
    )
  );

-- Step 4: Verification - Try to like a post from another domain (should fail)
-- This logic is now strictly enforced by the CHECK constraint in Step 3.

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check: Current User Domain
-- SELECT domain_id FROM profiles WHERE id = auth.uid();

-- Check: Post Domain
-- SELECT domain_id FROM posts WHERE id = 'some-post-id';

-- If domains don't match, INSERT INTO likes will fail.
-- ============================================================================
