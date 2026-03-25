-- ================================================================================
-- FIX 3: VERIFY LIKES_COUNT IS UPDATING
-- ================================================================================

-- Create trigger to update likes_count on like/unlike
CREATE OR REPLACE FUNCTION update_posts_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts_dim SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts_dim SET likes_count = likes_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS likes_count_trigger ON likes_fact;
CREATE TRIGGER likes_count_trigger
AFTER INSERT OR DELETE ON likes_fact
FOR EACH ROW EXECUTE FUNCTION update_posts_likes_count();

-- Sync existing likes counts
UPDATE posts_dim p 
SET likes_count = (
  SELECT COUNT(*) FROM likes_fact l WHERE l.post_id = p.id
);

-- ================================================================================
-- FIX 4: VERIFY COMMENTS_COUNT IS UPDATING
-- ================================================================================

-- Create trigger for comments_count
CREATE OR REPLACE FUNCTION update_posts_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts_dim SET comments_count = comments_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts_dim SET comments_count = comments_count - 1 WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS comments_count_trigger ON comments_fact;
CREATE TRIGGER comments_count_trigger
AFTER INSERT OR DELETE ON comments_fact
FOR EACH ROW EXECUTE FUNCTION update_posts_comments_count();

-- Sync existing comments counts
UPDATE posts_dim p 
SET comments_count = (
  SELECT COUNT(*) FROM comments_fact c WHERE c.post_id = p.id
);
