
-- Create notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    type TEXT NOT NULL, -- 'like', 'comment', 'connection'
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert notifications" ON public.notifications FOR INSERT WITH CHECK (true); -- Simplified for now

-- Function to handle notifications on like
CREATE OR REPLACE FUNCTION public.handle_like_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify if the liker is not the author
    IF (SELECT author_id FROM public.posts WHERE id = NEW.post_id) != NEW.user_id THEN
        INSERT INTO public.notifications (user_id, actor_id, type, post_id)
        VALUES (
            (SELECT author_id FROM public.posts WHERE id = NEW.post_id),
            NEW.user_id,
            'like',
            NEW.post_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for likes
CREATE TRIGGER on_like_notification
    AFTER INSERT ON public.likes
    FOR EACH ROW EXECUTE FUNCTION public.handle_like_notification();

-- Function to handle notifications on comment
CREATE OR REPLACE FUNCTION public.handle_comment_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Only notify if the commenter is not the author
    IF (SELECT author_id FROM public.posts WHERE id = NEW.post_id) != NEW.author_id THEN
        INSERT INTO public.notifications (user_id, actor_id, type, post_id)
        VALUES (
            (SELECT author_id FROM public.posts WHERE id = NEW.post_id),
            NEW.author_id,
            'comment',
            NEW.post_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for comments
CREATE TRIGGER on_comment_notification
    AFTER INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.handle_comment_notification();
