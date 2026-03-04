-- ============================================================
-- LinkSpec: Expand posts.content to TEXT (5,000 char support)
-- ============================================================
-- PostgreSQL can't ALTER a column type while a view depends on it.
-- Safe workaround: drop view → alter column → recreate view.
-- ============================================================

-- Step 1: Drop the dependent view temporarily
DROP VIEW IF EXISTS public.posts_with_stats;

-- Step 2: Expand content column to TEXT (no length limit)
ALTER TABLE public.posts
  ALTER COLUMN content TYPE TEXT;

-- Step 3: Recreate posts_with_stats exactly as before
--         (adjust the SELECT list if your view has extra columns)
CREATE OR REPLACE VIEW public.posts_with_stats AS
SELECT
  p.id,
  p.author_id,
  p.domain_id,
  p.content,
  p.image_url,
  p.views_count,
  p.shares_count,
  p.created_at,
  p.updated_at,
  COUNT(DISTINCT l.id)  AS like_count,
  COUNT(DISTINCT c.id)  AS comment_count,
  pr.full_name          AS author_name,
  pr.avatar_url         AS author_avatar,
  pr.domain_id          AS author_domain
FROM public.posts p
LEFT JOIN public.likes    l  ON l.post_id  = p.id
LEFT JOIN public.comments c  ON c.post_id  = p.id
LEFT JOIN public.profiles pr ON pr.id       = p.author_id
GROUP BY
  p.id,
  p.author_id,
  p.domain_id,
  p.content,
  p.image_url,
  p.views_count,
  p.shares_count,
  p.created_at,
  p.updated_at,
  pr.full_name,
  pr.avatar_url,
  pr.domain_id;

-- ============================================================
-- Done. posts.content is now TEXT (stores up to 1 GB).
-- The 5,000-char cap is enforced in Flutter via PostSanitizer.
-- ============================================================
