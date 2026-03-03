-- ==============================================================
-- Fix: Allow posting to Business and Global domains
-- Bug: INSERT RLS policy was missing Business and Global domains,
--      causing "permission denied" errors when posting to those feeds.
-- Run this in Supabase Dashboard > SQL Editor
-- ==============================================================

-- Drop the old restrictive INSERT policy
drop policy if exists "Users can post to any domain" on public.posts;

-- New INSERT policy: author can post to ANY of the 6 valid domains
create policy "Users can post to any domain"
  on public.posts for insert
  with check (
    auth.uid() = author_id
    and domain_id in ('Medical', 'IT/Software', 'Civil Engineering', 'Law', 'Business', 'Global')
  );

-- Also fix the SELECT policy to allow users in Business/Global to see their posts:
-- The old policy uses a subquery that could cause recursion issues.
-- Let's replace it with the SECURITY DEFINER helper approach.

-- Helper function (create or re-use if already exists)
create or replace function get_user_domain(user_id uuid)
returns text as $$
  select domain_id from public.profiles where id = user_id limit 1;
$$ language sql security definer stable;

-- Drop old SELECT policies
drop policy if exists "Users see posts only in their domain"   on public.posts;
drop policy if exists "Users can view posts in their domain"   on public.posts;
drop policy if exists "Domain members can view posts"          on public.posts;

-- New SELECT policy: user sees posts in their current domain
create policy "Users see posts only in their domain"
  on public.posts for select
  using (
    domain_id = get_user_domain(auth.uid())
    or author_id = auth.uid()  -- always see own posts
  );
