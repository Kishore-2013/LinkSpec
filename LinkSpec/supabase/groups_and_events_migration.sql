-- Tables for Groups and Events (Phase 2 Extension)

-- 1. Create Groups table
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  cover_url TEXT,
  member_count INTEGER DEFAULT 0,
  domain_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create Events table
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  date TIMESTAMPTZ NOT NULL,
  location TEXT NOT NULL,
  image_url TEXT,
  attendee_count INTEGER DEFAULT 0,
  domain_id TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Enable RLS
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies (Domain-gated)

-- Groups Policies
DROP POLICY IF EXISTS "Users can view groups in same domain" ON public.groups;
CREATE POLICY "Users can view groups in same domain" 
  ON public.groups FOR SELECT 
  USING (domain_id = (SELECT domain_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can create groups in same domain" ON public.groups;
CREATE POLICY "Users can create groups in same domain" 
  ON public.groups FOR INSERT 
  WITH CHECK (domain_id = (SELECT domain_id FROM profiles WHERE id = auth.uid()));

-- Events Policies
DROP POLICY IF EXISTS "Users can view events in same domain" ON public.events;
CREATE POLICY "Users can view events in same domain" 
  ON public.events FOR SELECT 
  USING (domain_id = (SELECT domain_id FROM profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "Users can create events in same domain" ON public.events;
CREATE POLICY "Users can create events in same domain" 
  ON public.events FOR INSERT 
  WITH CHECK (domain_id = (SELECT domain_id FROM profiles WHERE id = auth.uid()));

-- 5. Add initial data for the Medical domain
INSERT INTO public.groups (name, description, cover_url, member_count, domain_id)
VALUES 
('Medical Professionals Network', 'A group for doctors, nurses, and medical students.', 'https://images.unsplash.com/photo-1576091160550-217359f4810a?q=80&w=2070&auto=format&fit=crop', 1200, 'Medical'),
('Digital Health Innovation', 'Exploring the intersection of technology and healthcare.', 'https://images.unsplash.com/photo-1504868584819-f8e905263543?q=80&w=2076&auto=format&fit=crop', 850, 'Medical'),
('Future Surgeons', 'Connecting aspiring surgeons worldwide.', 'https://images.unsplash.com/photo-1551076805-e1869033e561?q=80&w=1932&auto=format&fit=crop', 3400, 'Medical');

INSERT INTO public.events (title, description, date, location, image_url, attendee_count, domain_id)
VALUES 
('Medical AI Conference 2026', 'Exploring AI integration in modern medicine.', now() + interval '5 days', 'Hyderabad International Convention Centre', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?q=80&w=2070&auto=format&fit=crop', 320, 'Medical'),
('Nursing Excellence Awards', 'Celebrating the best in nursing care.', now() + interval '12 days', 'Mumbai', NULL, 150, 'Medical'),
('Healthcare Leadership Summit', 'Bringing hospital leaders together.', now() - interval '3 days', 'Bangalore', NULL, 200, 'Medical');
