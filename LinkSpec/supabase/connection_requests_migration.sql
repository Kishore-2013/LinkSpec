-- ============================================================
-- connection_requests table: for mutual "Connect" feature
-- ============================================================
-- Status values: 'pending' | 'accepted'
-- The existing `connections` table handles one-way follows.

create table if not exists public.connection_requests (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  -- Prevent duplicate requests
  unique (sender_id, receiver_id)
);

-- Index for fast lookups
create index if not exists idx_cr_sender   on public.connection_requests (sender_id);
create index if not exists idx_cr_receiver on public.connection_requests (receiver_id);

-- Enable Row Level Security
alter table public.connection_requests enable row level security;

-- Policies
-- Anyone in the same domain can see requests involving them
create policy "Users can view their own connection requests"
  on public.connection_requests for select
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- Only the sender can create a request
create policy "Users can send connection requests"
  on public.connection_requests for insert
  with check (auth.uid() = sender_id);

-- The receiver can update (accept) the request; sender can also update (withdraw by deleting)
create policy "Receiver can accept connection requests"
  on public.connection_requests for update
  using (auth.uid() = receiver_id);

-- Either party can delete the request
create policy "Either party can remove connection"
  on public.connection_requests for delete
  using (auth.uid() = sender_id or auth.uid() = receiver_id);
