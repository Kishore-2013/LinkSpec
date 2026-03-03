-- ==============================================================
-- Migration: Add gender column to profiles table
-- ==============================================================

-- 1. Add the gender column if it doesn't exist
do $$
begin
  if not exists (select 1 from information_schema.columns where table_name = 'profiles' and column_name = 'gender') then
    alter table public.profiles add column gender text;
  end if;
end $$;

-- 2. Update existing rows to have industry match domain_id if industry is null
update public.profiles set industry = domain_id where industry is null;
