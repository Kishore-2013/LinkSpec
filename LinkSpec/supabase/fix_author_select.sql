-- Run this in Supabase SQL Editor
-- Fix: Authors must be able to read back their own posts (even cross-domain)

-- First, check remaining policies
-- SELECT policyname, cmd, qual, with_check FROM pg_policies WHERE tablename = 'posts';

-- Add policy: authors can always view their own posts
DROP POLICY IF EXISTS "Authors can view their own posts" ON public.posts;

CREATE POLICY "Authors can view their own posts"
  ON public.posts FOR SELECT
  USING (auth.uid() = author_id);
