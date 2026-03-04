-- Add support for dynamic application forms
ALTER TABLE jobs ADD COLUMN IF NOT EXISTS application_form_schema jsonb DEFAULT '[]'::jsonb;

-- Add answers column to applications
ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS answers_json jsonb DEFAULT '{}'::jsonb;

-- Update RLS to ensure HR users can only see applicants for their own jobs (already exists, but just for completeness)
-- The existing policy "HR posters can view applicants" should cover this.
