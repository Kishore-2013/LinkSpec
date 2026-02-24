-- Add insight columns to posts table
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS shares_count INTEGER DEFAULT 0;

-- Function to increment views atomically
CREATE OR REPLACE FUNCTION increment_post_views(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.posts
  SET views_count = views_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment shares atomically
CREATE OR REPLACE FUNCTION increment_post_shares(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.posts
  SET shares_count = shares_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;
