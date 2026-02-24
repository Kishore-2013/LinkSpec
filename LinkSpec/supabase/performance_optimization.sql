-- Run this in Supabase SQL Editor
-- Optimization: Add indexes to speed up domain-filtered and author-filtered queries

-- Indexes for the 'posts' table
CREATE INDEX IF NOT EXISTS idx_posts_domain_id ON public.posts (domain_id);
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON public.posts (author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts (created_at DESC);

-- Indexes for the 'profiles' table
CREATE INDEX IF NOT EXISTS idx_profiles_domain_id ON public.profiles (domain_id);

-- Indexes for the 'connections' table (for fast follow checks)
CREATE INDEX IF NOT EXISTS idx_connections_follower_id ON public.connections (follower_id);
CREATE INDEX IF NOT EXISTS idx_connections_following_id ON public.connections (following_id);

-- Indexes for 'connection_requests'
CREATE INDEX IF NOT EXISTS idx_conn_req_sender_id ON public.connection_requests (sender_id);
CREATE INDEX IF NOT EXISTS idx_conn_req_receiver_id ON public.connection_requests (receiver_id);
CREATE INDEX IF NOT EXISTS idx_conn_req_status ON public.connection_requests (status);
