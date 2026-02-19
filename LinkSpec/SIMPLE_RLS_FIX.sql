-- ============================================================================
-- DIRECT FIX: Bypass the helper function approach
-- ============================================================================
-- The get_user_domain() function might not be working
-- Let's use a direct approach instead
-- ============================================================================

-- Step 1: Drop ALL existing policies on posts
DROP POLICY IF EXISTS "Users can view posts in same domain" ON posts;
DROP POLICY IF EXISTS "Users can insert own posts" ON posts;
DROP POLICY IF EXISTS "Users can update own posts" ON posts;
DROP POLICY IF EXISTS "Users can delete own posts" ON posts;

-- Step 2: Create a SIMPLER SELECT policy that doesn't use helper function
CREATE POLICY "Users can view posts in same domain"
  ON posts
  FOR SELECT
  USING (
    -- User can see posts where the post's domain_id matches their profile's domain_id
    domain_id IN (
      SELECT domain_id 
      FROM profiles 
      WHERE id = auth.uid()
    )
  );

-- Step 3: Recreate INSERT policy
CREATE POLICY "Users can insert own posts"
  ON posts
  FOR INSERT
  WITH CHECK (
    auth.uid() = author_id
  );

-- Step 4: Recreate UPDATE policy
CREATE POLICY "Users can update own posts"
  ON posts
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- Step 5: Recreate DELETE policy
CREATE POLICY "Users can delete own posts"
  ON posts
  FOR DELETE
  USING (auth.uid() = author_id);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Check 1: What's your domain?
SELECT 
  id,
  full_name,
  domain_id as my_domain
FROM profiles
WHERE id = auth.uid();

-- Check 2: What posts exist and their domains?
SELECT 
  p.id,
  LEFT(p.content, 50) as content_preview,
  p.domain_id as post_domain,
  pr.full_name as author,
  pr.domain_id as author_domain
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
ORDER BY p.created_at DESC;

-- Check 3: What posts can YOU see (with RLS applied)?
SELECT 
  id,
  LEFT(content, 50) as content_preview,
  domain_id
FROM posts
ORDER BY created_at DESC;

-- This should ONLY show posts matching your domain!

-- ============================================================================
