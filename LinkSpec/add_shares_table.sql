-- ============================================================================
-- MIGRATION: Add Shares Table for Internal Sharing
-- ============================================================================

CREATE TABLE IF NOT EXISTS shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraint: Cannot share with yourself (optional but good)
  CONSTRAINT cannot_share_with_self CHECK (sender_id != receiver_id)
);

-- Enable RLS
ALTER TABLE shares ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see shares they sent or received
CREATE POLICY "Users can view their own shares"
  ON shares
  FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Policy: Users can only share posts from their domain with users in their domain
CREATE POLICY "Users can share within domain"
  ON shares
  FOR INSERT
  WITH CHECK (
    -- 1. Sender must be the authenticated user
    auth.uid() = sender_id
    AND
    -- 2. Sender and Receiver must be in the same domain
    (SELECT domain_id FROM profiles WHERE id = sender_id) = (SELECT domain_id FROM profiles WHERE id = receiver_id)
    AND
    -- 3. The post must belong to that same domain
    (SELECT domain_id FROM posts WHERE id = post_id) = (SELECT domain_id FROM profiles WHERE id = sender_id)
  );

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_shares_receiver_id ON shares(receiver_id);
CREATE INDEX IF NOT EXISTS idx_shares_sender_id ON shares(sender_id);
