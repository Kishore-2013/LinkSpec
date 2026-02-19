
-- Create saved_jobs table
CREATE TABLE IF NOT EXISTS public.saved_jobs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    job_id UUID REFERENCES public.jobs(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, job_id)
);

-- Enable RLS
ALTER TABLE public.saved_jobs ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own saved jobs" ON public.saved_jobs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can save jobs" ON public.saved_jobs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unsave their jobs" ON public.saved_jobs FOR DELETE USING (auth.uid() = user_id);

-- View to include job details with saved status (optional but helpful)
CREATE OR REPLACE VIEW public.jobs_with_saved_status AS
SELECT 
    j.*,
    EXISTS (
        SELECT 1 FROM public.saved_jobs sj 
        WHERE sj.job_id = j.id AND sj.user_id = auth.uid()
    ) as is_saved
FROM 
    public.jobs j;
