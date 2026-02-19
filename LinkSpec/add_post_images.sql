-- ============================================================================
-- MIGRATION: Add Image Support to Posts
-- ============================================================================

-- 1. Add image_url column to posts table
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. Create bucket for post images (if not exists)
-- Note: This is usually done via Supabase Dashboard but we can use SQL
INSERT INTO storage.buckets (id, name, public)
SELECT 'post-images', 'post-images', true
WHERE NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'post-images'
);

-- 3. Storage RLS Policies
-- Allow anyone to view images (public bucket)
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'post-images' );

-- Allow authenticated users to upload images to the bucket
CREATE POLICY "Users can upload post images"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'post-images' 
    AND auth.role() = 'authenticated'
);

-- Allow users to delete their own images
CREATE POLICY "Users can delete own post images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'post-images' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);
