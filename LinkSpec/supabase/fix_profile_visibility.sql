-- Run this in Supabase SQL Editor
-- Allow users to see the profile (name, avatar) of anyone who has
-- posted in their domain — needed for cross-domain post author display

DROP POLICY IF EXISTS "Anyone can view basic profile info" ON public.profiles;

CREATE POLICY "Anyone can view basic profile info"
  ON public.profiles FOR SELECT
  USING (true);
