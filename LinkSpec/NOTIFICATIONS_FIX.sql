
-- 1. Modified Trigger to allow self-notifications for testing
-- (In production, you'd usually keep the != check, but let's enable it so the user can see it works)
CREATE OR REPLACE FUNCTION public.handle_like_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id)
    VALUES (
        (SELECT author_id FROM public.posts WHERE id = NEW.post_id),
        NEW.user_id,
        'like',
        NEW.post_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.handle_comment_notification()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type, post_id)
    VALUES (
        (SELECT author_id FROM public.posts WHERE id = NEW.post_id),
        NEW.author_id,
        'comment',
        NEW.post_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Drop and Recreate triggers to ensure they are clean
DROP TRIGGER IF EXISTS on_like_notification ON public.likes;
CREATE TRIGGER on_like_notification
    AFTER INSERT ON public.likes
    FOR EACH ROW EXECUTE FUNCTION public.handle_like_notification();

DROP TRIGGER IF EXISTS on_comment_notification ON public.comments;
CREATE TRIGGER on_comment_notification
    AFTER INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.handle_comment_notification();

-- 3. HELPER: Test function to manually trigger a notification
-- Usage: SELECT public.send_test_notification('YOUR_USER_ID_HERE');
CREATE OR REPLACE FUNCTION public.send_test_notification(target_user_id UUID)
RETURNS void AS $$
BEGIN
    INSERT INTO public.notifications (user_id, actor_id, type)
    VALUES (target_user_id, target_user_id, 'connection');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
