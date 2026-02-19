-- Step 1: Add cover_url column to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS cover_url TEXT;

-- Step 2: Create the 'profiles' storage bucket (public)
INSERT INTO storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true)
ON CONFLICT (id) DO NOTHING;

-- Step 3: Drop existing policies if they exist, then recreate
DROP POLICY IF EXISTS "Users can upload their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Profile images are publicly accessible" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;

-- Allow authenticated users to upload to their own folder
CREATE POLICY "Users can upload their own profile images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profiles');

-- Allow public read access to all profile images
CREATE POLICY "Profile images are publicly accessible"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profiles');

-- Allow users to update their own files
CREATE POLICY "Users can update their own profile images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profiles');

-- Allow users to delete their own files
CREATE POLICY "Users can delete their own profile images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'profiles');
