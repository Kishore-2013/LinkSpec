-- Run this in Supabase SQL Editor
-- Drops the old conflicting policies on posts

-- Drop old SELECT policy that checks domain against author's profile
DROP POLICY IF EXISTS "Users can view posts in same domain" ON public.posts;

-- Drop old INSERT policy (redundant, our new one covers it)
DROP POLICY IF EXISTS "Users can insert own posts" ON public.posts;
