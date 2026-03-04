-- Create job_applications table
CREATE TABLE IF NOT EXISTS job_applications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  job_id uuid REFERENCES jobs(id) ON DELETE CASCADE NOT NULL,
  applied_at timestamptz DEFAULT now(),
  UNIQUE(user_id, job_id)
);

-- Enable RLS
ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own applications"
  ON job_applications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can apply for jobs"
  ON job_applications FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Add real-time support if not already enabled for jobs (optional, but good for "New" badge)
-- ALTER publication supabase_realtime ADD TABLE jobs;
