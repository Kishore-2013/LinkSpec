-- ==============================================================
-- LinkSpec Full Migration Script
-- Run this entire script in Supabase Dashboard > SQL Editor
-- Safe to run multiple times (idempotent)
-- ==============================================================


-- ==============================================================
-- PART 1: connection_requests table (for mutual Connect feature)
-- ==============================================================

create table if not exists public.connection_requests (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  unique (sender_id, receiver_id)
);

create index if not exists idx_cr_sender   on public.connection_requests (sender_id);
create index if not exists idx_cr_receiver on public.connection_requests (receiver_id);

alter table public.connection_requests enable row level security;

-- Drop first so re-runs do not error
drop policy if exists "Users can view their own connection requests" on public.connection_requests;
drop policy if exists "Users can send connection requests"           on public.connection_requests;
drop policy if exists "Receiver can accept connection requests"      on public.connection_requests;
drop policy if exists "Either party can remove connection"           on public.connection_requests;

create policy "Users can view their own connection requests"
  on public.connection_requests for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Users can send connection requests"
  on public.connection_requests for insert
  with check (auth.uid() = sender_id);

create policy "Receiver can accept connection requests"
  on public.connection_requests for update
  using (auth.uid() = receiver_id);

create policy "Either party can remove connection"
  on public.connection_requests for delete
  using (auth.uid() = sender_id or auth.uid() = receiver_id);


-- ==============================================================
-- PART 2: Cross-domain post support — RLS policies
-- ==============================================================

-- Drop old INSERT policies
drop policy if exists "Users can create posts in their domain" on public.posts;
drop policy if exists "Users can insert their own posts"       on public.posts;
drop policy if exists "Users can post to any domain"          on public.posts;

-- New INSERT policy: author can post to any valid domain
create policy "Users can post to any domain"
  on public.posts for insert
  with check (
    auth.uid() = author_id
    and domain_id in ('Medical', 'IT/Software', 'Civil Engineering', 'Law')
  );

-- Drop old SELECT policies
drop policy if exists "Users can view posts in their domain"  on public.posts;
drop policy if exists "Domain members can view posts"         on public.posts;
drop policy if exists "Users see posts only in their domain"  on public.posts;

-- New SELECT policy: viewers only see posts targeted at their domain
create policy "Users see posts only in their domain"
  on public.posts for select
  using (
    domain_id = (
      select domain_id
      from public.profiles
      where id = auth.uid()
      limit 1
    )
  );


-- ==============================================================
-- PART 3: Fix the BEFORE INSERT trigger on posts
-- ==============================================================
-- The original trigger unconditionally overwrites domain_id with
-- the author's profile domain on every INSERT, making cross-domain
-- posting impossible. This update makes it only fall back to the
-- author's domain when domain_id is NOT explicitly provided.
-- ==============================================================

create or replace function set_post_domain()
returns trigger as $$
begin
  -- Only auto-assign if the caller did NOT explicitly set a domain_id
  if NEW.domain_id is null then
    NEW.domain_id := (
      select domain_id
      from public.profiles
      where id = NEW.author_id
      limit 1
    );
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

-- The trigger name stays the same; CREATE OR REPLACE on the function
-- is enough — no need to drop/recreate the trigger itself.
