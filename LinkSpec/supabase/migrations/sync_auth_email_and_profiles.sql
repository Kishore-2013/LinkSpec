-- Migration: Sync email from auth.users to public.profiles and add secure password storage
-- 1. Add email and custom_password columns to profiles
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS custom_password TEXT;

-- 2. Create or replace the function to sync email from auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user_sync()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, domain_id, mother_domain)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'domain_id', 'General'),
    COALESCE(NEW.raw_user_meta_data->>'domain_id', 'General')
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create a trigger on auth.users (requires superuser or bypass)
-- Note: In managed Supabase, this trigger is usually set up via the dashboard or a migration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_sync();

-- 4. Secure the custom_password column using RLS
-- Ensure 'select' permissions exclude the password hash from public view
-- We do this by creating a view without the password or by restrictive RLS
-- Here we ensure the current user can only see their own password hash if needed, 
-- but others cannot see it via public profiles list.

CREATE POLICY "Users can only see their own password hash"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

-- For general public view (names, avatars, etc), the password column should be excluded in the app layer 
-- or by creating a public_profiles view.
