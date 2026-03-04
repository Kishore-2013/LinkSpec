-- Add tag column to profiles if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS tag text DEFAULT 'User';

-- Add posted_by column to jobs
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS posted_by uuid REFERENCES profiles(id) ON DELETE CASCADE;

-- Backfill posted_by for existing jobs (optional, depends on if you want to assign them to a specific user)
-- UPDATE jobs SET posted_by = 'SOME_USER_ID' WHERE posted_by IS NULL;

-- Update RLS on jobs table
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Jobs are viewable by everyone" ON jobs;
DROP POLICY IF EXISTS "HR users can insert jobs" ON jobs;
DROP POLICY IF EXISTS "Jobs are deletable by poster" ON jobs;

CREATE POLICY "Jobs are viewable by everyone" 
  ON jobs FOR SELECT 
  USING (true);

-- Requirement 2 & 3: Only HR users can insert.
-- We check if the profile's tag is 'HR'.
CREATE POLICY "HR users can insert jobs" 
  ON jobs FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.tag = 'HR'
    )
  );

CREATE POLICY "Jobs are deletable by poster" 
  ON jobs FOR DELETE 
  USING (auth.uid() = posted_by);

-- Requirement 3: Applicant Tracking (HR Dashboard)
-- HR users can see applicants for their own jobs.
DROP POLICY IF EXISTS "HR posters can view applicants" ON job_applications;
CREATE POLICY "HR posters can view applicants" 
  ON job_applications FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM jobs 
      WHERE jobs.id = job_applications.job_id 
      AND jobs.posted_by = auth.uid()
    )
    OR auth.uid() = user_id -- Users can still see their own applications
  );
