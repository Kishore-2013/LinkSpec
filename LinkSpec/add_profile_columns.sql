-- Add new profile sections as JSONB for flexibility
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS experience JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS education JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS projects JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS skills JSONB DEFAULT '[]'::jsonb;
