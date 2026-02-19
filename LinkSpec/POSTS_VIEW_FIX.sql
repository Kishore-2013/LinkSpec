
-- Drop the existing view first to avoid column mismatch errors
DROP VIEW IF EXISTS public.posts_with_stats;

-- Recreate the view with the correct sequence of columns
CREATE VIEW public.posts_with_stats AS
SELECT 
    p.*,
    pr.full_name as author_name,
    pr.avatar_url as author_avatar,
    pr.domain_id as author_domain,
    (SELECT COUNT(*) FROM public.likes l WHERE l.post_id = p.id) as like_count,
    (SELECT COUNT(*) FROM public.comments c WHERE c.post_id = p.id) as comment_count
FROM 
    public.posts p
LEFT JOIN 
    public.profiles pr ON p.author_id = pr.id;

-- Grant access to the view
GRANT SELECT ON public.posts_with_stats TO anon, authenticated;
