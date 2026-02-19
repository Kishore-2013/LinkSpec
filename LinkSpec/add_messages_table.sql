-- ============================================================================
-- MIGRATION: Add Messages & Chat Feature
-- ============================================================================

-- 1. Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT,
  post_id UUID REFERENCES posts(id) ON DELETE SET NULL, -- Link to a shared post
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see messages they sent or received
CREATE POLICY "Users can view their own messages"
  ON messages
  FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

-- Policy: Users can only message within their domain
CREATE POLICY "Users can message within domain"
  ON messages
  FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND
    -- Sender and Receiver must be in the same domain
    (SELECT domain_id FROM profiles WHERE id = sender_id) = (SELECT domain_id FROM profiles WHERE id = receiver_id)
  );

-- 2. Index for performance
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at DESC);
