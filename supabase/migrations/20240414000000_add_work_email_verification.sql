-- ================================================================================
-- ADD WORK EMAIL VERIFICATION COLUMNS TO PROFILES_DIM
-- ================================================================================

-- 1. Add columns to profiles_dim
ALTER TABLE profiles_dim 
ADD COLUMN IF NOT EXISTS work_email TEXT,
ADD COLUMN IF NOT EXISTS is_work_email_verified BOOLEAN DEFAULT FALSE;

-- 2. Add comment for clarity
COMMENT ON COLUMN profiles_dim.work_email IS 'Professional/Work email for domain verification';
COMMENT ON COLUMN profiles_dim.is_work_email_verified IS 'True if the work email has been verified via OTP';

-- 3. Update RLS if necessary (Optional, depending on your existing policies)
-- Usually, users should be able to read these fields on any profile, 
-- but only update their own. Existing policies on profiles_dim likely cover this.
