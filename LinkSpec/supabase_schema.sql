-- ============================================================================
-- LinkSpec: Domain-Gated Vertical Social Network
-- Supabase PostgreSQL Schema with Row Level Security (RLS)
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. PROFILES TABLE
-- ============================================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  domain_id TEXT NOT NULL CHECK (domain_id IN ('Medical', 'IT/Software', 'Civil Engineering', 'Law')),
  bio TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Helper function to get user's domain (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION get_user_domain(user_id UUID)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT domain_id FROM profiles WHERE id = user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS Policy: Users can view their own profile OR profiles in their domain
CREATE POLICY "Users can view profiles in same domain"
  ON profiles
  FOR SELECT
  USING (
    auth.uid() = id  -- Can always see own profile
    OR 
    domain_id = get_user_domain(auth.uid())  -- Or profiles in same domain
  );

-- RLS Policy: Users can insert their own profile
CREATE POLICY "Users can insert own profile"
  ON profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- RLS Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Index for faster domain lookups
CREATE INDEX idx_profiles_domain_id ON profiles(domain_id);

-- ============================================================================
-- 2. POSTS TABLE
-- ============================================================================
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  domain_id TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on posts
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only view posts in their domain
CREATE POLICY "Users can view posts in same domain"
  ON posts
  FOR SELECT
  USING (
    domain_id = get_user_domain(auth.uid())
  );

-- RLS Policy: Users can insert posts (domain_id auto-inherited)
CREATE POLICY "Users can insert own posts"
  ON posts
  FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    domain_id = get_user_domain(auth.uid())
  );

-- RLS Policy: Users can update their own posts
CREATE POLICY "Users can update own posts"
  ON posts
  FOR UPDATE
  USING (auth.uid() = author_id)
  WITH CHECK (
    auth.uid() = author_id AND
    domain_id = (
      SELECT domain_id FROM profiles WHERE id = auth.uid()
    )
  );

-- RLS Policy: Users can delete their own posts
CREATE POLICY "Users can delete own posts"
  ON posts
  FOR DELETE
  USING (auth.uid() = author_id);

-- Indexes for performance
CREATE INDEX idx_posts_domain_id ON posts(domain_id);
CREATE INDEX idx_posts_author_id ON posts(author_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- ============================================================================
-- 3. LIKES TABLE
-- ============================================================================
CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id) -- Prevent duplicate likes
);

-- Enable RLS on likes
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only like posts in their domain
CREATE POLICY "Users can view likes in same domain"
  ON likes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM posts p
      INNER JOIN profiles pr ON pr.id = auth.uid()
      WHERE p.id = likes.post_id AND p.domain_id = pr.domain_id
    )
  );

-- RLS Policy: Users can insert likes only for posts in their domain
CREATE POLICY "Users can like posts in same domain"
  ON likes
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM posts p
      INNER JOIN profiles pr ON pr.id = auth.uid()
      WHERE p.id = post_id AND p.domain_id = pr.domain_id
    )
  );

-- RLS Policy: Users can delete their own likes
CREATE POLICY "Users can delete own likes"
  ON likes
  FOR DELETE
  USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX idx_likes_post_id ON likes(post_id);
CREATE INDEX idx_likes_user_id ON likes(user_id);

-- ============================================================================
-- 4. CONNECTIONS TABLE (Social Graph)
-- ============================================================================
CREATE TABLE connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  following_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(follower_id, following_id), -- Prevent duplicate connections
  CHECK (follower_id != following_id) -- Prevent self-following
);

-- Enable RLS on connections
ALTER TABLE connections ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view connections in their domain
CREATE POLICY "Users can view connections in same domain"
  ON connections
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p1, profiles p2, profiles curr_user
      WHERE curr_user.id = auth.uid()
        AND p1.id = connections.follower_id
        AND p2.id = connections.following_id
        AND p1.domain_id = curr_user.domain_id
        AND p2.domain_id = curr_user.domain_id
    )
  );

-- RLS Policy: Users can follow others in their domain
CREATE POLICY "Users can follow in same domain"
  ON connections
  FOR INSERT
  WITH CHECK (
    auth.uid() = follower_id AND
    EXISTS (
      SELECT 1 FROM profiles p1, profiles p2
      WHERE p1.id = follower_id
        AND p2.id = following_id
        AND p1.domain_id = p2.domain_id
    )
  );

-- RLS Policy: Users can unfollow (delete their own connections)
CREATE POLICY "Users can unfollow"
  ON connections
  FOR DELETE
  USING (auth.uid() = follower_id);

-- Indexes for performance
CREATE INDEX idx_connections_follower_id ON connections(follower_id);
CREATE INDEX idx_connections_following_id ON connections(following_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to automatically set domain_id on post creation
CREATE OR REPLACE FUNCTION set_post_domain()
RETURNS TRIGGER AS $$
BEGIN
  NEW.domain_id := (SELECT domain_id FROM profiles WHERE id = NEW.author_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-set domain_id on posts
CREATE TRIGGER trigger_set_post_domain
  BEFORE INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION set_post_domain();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VIEWS FOR ANALYTICS (Optional but useful)
-- ============================================================================

-- View: Post with like count
CREATE OR REPLACE VIEW posts_with_stats AS
SELECT 
  p.*,
  pr.full_name as author_name,
  pr.avatar_url as author_avatar,
  COUNT(DISTINCT l.id) as like_count
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
LEFT JOIN likes l ON p.id = l.post_id
GROUP BY p.id, pr.full_name, pr.avatar_url;

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Note: In production, profiles are created via Flutter app after user registration
-- This is just for testing the schema

-- INSERT INTO profiles (id, full_name, domain_id, bio) VALUES
-- ('00000000-0000-0000-0000-000000000001', 'Dr. Sarah Johnson', 'Medical', 'Cardiologist with 10 years experience'),
-- ('00000000-0000-0000-0000-000000000002', 'John Doe', 'IT/Software', 'Full Stack Developer'),
-- ('00000000-0000-0000-0000-000000000003', 'Emily Chen', 'Civil Engineering', 'Structural Engineer');
