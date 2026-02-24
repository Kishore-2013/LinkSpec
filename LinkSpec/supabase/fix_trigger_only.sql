-- Run ONLY this in Supabase SQL Editor
-- Fixes the trigger so cross-domain posts work

CREATE OR REPLACE FUNCTION set_post_domain()
RETURNS TRIGGER AS $func$
BEGIN
  IF NEW.domain_id IS NULL THEN
    NEW.domain_id := (
      SELECT domain_id
      FROM public.profiles
      WHERE id = NEW.author_id
      LIMIT 1
    );
  END IF;
  RETURN NEW;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;
