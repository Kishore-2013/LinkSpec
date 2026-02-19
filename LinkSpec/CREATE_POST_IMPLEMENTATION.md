# Create Post Implementation - Automatic Domain Assignment

## 🎯 Overview

When a user creates a post in LinkSpec, the **domain_id is automatically attached** to the post. The user doesn't need to manually specify it, and the Flutter app doesn't need to fetch it separately. This is handled by a **PostgreSQL database trigger**.

---

## 📍 The Flutter Function (Already Implemented!)

### Location: `lib/services/supabase_service.dart` (Lines 108-129)

```dart
/// Create a new post
/// Domain ID is automatically set by database trigger
static Future<Map<String, dynamic>> createPost({
  required String content,
}) async {
  final userId = _client.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  final response = await _client
      .from('posts')
      .insert({
        'author_id': userId,  // ← Only need to provide author_id
        'content': content,   // ← and content
        // domain_id is NOT provided here! ✨
      })
      .select()
      .single();

  return response;
}
```

### 🔑 Key Points:

1. **No domain_id in the insert** - Notice we only insert `author_id` and `content`
2. **User authentication** - Gets current user's ID from Supabase auth
3. **Returns the created post** - `.select().single()` returns the full post object with domain_id

---

## ✨ The Magic: Database Trigger

### Location: `supabase_schema.sql` (Lines 217-230)

The domain_id is automatically set by this PostgreSQL trigger:

```sql
-- Function to automatically set domain_id on post creation
CREATE OR REPLACE FUNCTION set_post_domain()
RETURNS TRIGGER AS $$
BEGIN
  -- Fetch the author's domain_id from their profile
  NEW.domain_id := (SELECT domain_id FROM profiles WHERE id = NEW.author_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger that runs BEFORE INSERT on posts table
CREATE TRIGGER trigger_set_post_domain
  BEFORE INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION set_post_domain();
```

### How It Works:

```
1. Flutter sends INSERT with only author_id and content
   ↓
2. PostgreSQL receives the INSERT
   ↓
3. BEFORE INSERT trigger fires
   ↓
4. set_post_domain() function executes:
   - Looks up author's profile
   - Gets their domain_id
   - Sets NEW.domain_id to that value
   ↓
5. INSERT completes with domain_id automatically filled
   ↓
6. Post is saved with correct domain_id
```

---

## 🎨 The UI: CreatePostDialog

### Location: `lib/widgets/create_post_dialog.dart`

You already have a beautiful dialog for creating posts:

```dart
Future<void> _createPost() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    // Call the service - domain_id is auto-attached!
    await SupabaseService.createPost(
      content: _contentController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
      widget.onPostCreated?.call();  // Refresh feed
      _showSuccessSnackBar('Post created successfully!');
    }
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Error creating post: $e');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

### Features:

- ✅ Form validation (min 3 characters)
- ✅ Character counter (max 500 characters)
- ✅ Loading state
- ✅ Error handling
- ✅ Success feedback
- ✅ Auto-refresh feed after posting

---

## 🔐 Security: Double Protection

### 1. Database Trigger (Primary)

The trigger **automatically sets** the domain_id based on the author's profile.

### 2. RLS Policy (Validation)

Even if someone tries to manually set a different domain_id, the RLS policy blocks it:

```sql
CREATE POLICY "Users can insert posts in own domain"
  ON posts
  FOR INSERT
  WITH CHECK (
    auth.uid() = author_id AND
    domain_id = (
      SELECT domain_id FROM profiles WHERE id = auth.uid()
    )
  );
```

**Translation**: "You can only insert posts where the domain_id matches YOUR domain_id"

---

## 📊 Complete Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  User clicks "Post" button in CreatePostDialog              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Flutter: SupabaseService.createPost(content: "Hello!")     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Client: INSERT INTO posts                         │
│  {                                                           │
│    author_id: "user-uuid-123",                              │
│    content: "Hello!"                                         │
│    // domain_id is NOT provided                             │
│  }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL: BEFORE INSERT trigger fires                    │
│  - Looks up profiles table                                  │
│  - Finds author's domain_id = "Medical"                     │
│  - Sets NEW.domain_id = "Medical"                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL: RLS Policy validates                           │
│  - Checks: domain_id == user's domain_id                    │
│  - ✅ "Medical" == "Medical" → PASS                         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL: INSERT completes                               │
│  Post saved with:                                           │
│  {                                                           │
│    id: "post-uuid-456",                                     │
│    author_id: "user-uuid-123",                              │
│    content: "Hello!",                                        │
│    domain_id: "Medical",  ← Auto-set by trigger!            │
│    created_at: "2026-02-17T21:00:00Z"                       │
│  }                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase: Returns created post to Flutter                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Flutter: Shows success message, refreshes feed             │
│  New post appears in feed for all Medical domain users      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing the Automatic Domain Assignment

### Test 1: Verify domain_id is set correctly

```dart
// Create a post
final post = await SupabaseService.createPost(
  content: "Test post",
);

// Check the returned post has domain_id
print('Post domain_id: ${post['domain_id']}');
print('Expected: Medical (or whatever your domain is)');

// ✅ EXPECTED: domain_id matches your profile's domain_id
```

### Test 2: Cross-domain visibility

```
User A (Medical):
  1. Creates post: "Medical conference next week"
  2. Post is saved with domain_id = "Medical"

User B (IT/Software):
  1. Checks feed
  2. ✅ EXPECTED: Does NOT see User A's post

User C (Medical):
  1. Checks feed
  2. ✅ EXPECTED: DOES see User A's post
```

### Test 3: Direct database inspection

```sql
-- In Supabase SQL Editor
SELECT id, author_id, content, domain_id
FROM posts
ORDER BY created_at DESC
LIMIT 5;

-- ✅ EXPECTED: All posts have domain_id populated
-- ✅ EXPECTED: domain_id matches the author's profile domain_id
```

---

## 🎨 UI Components

### CreatePostDialog Features

1. **Multi-line text input** - Up to 500 characters
2. **Character counter** - Shows remaining characters
3. **Form validation** - Minimum 3 characters required
4. **Loading state** - Spinner while posting
5. **Error handling** - Shows error message if post fails
6. **Success feedback** - Green snackbar on success
7. **Auto-refresh** - Calls `onPostCreated()` to refresh feed

### Usage in Home Screen

```dart
// In home_screen.dart
void _showCreatePostDialog() {
  showDialog(
    context: context,
    builder: (context) => CreatePostDialog(
      onPostCreated: () {
        _refreshPosts();  // Refresh feed to show new post
      },
    ),
  );
}
```

---

## 🔧 Alternative Approach (Manual Fetch)

If you wanted to **manually fetch and set** the domain_id (not recommended, but possible):

```dart
static Future<Map<String, dynamic>> createPostManual({
  required String content,
}) async {
  final userId = _client.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  // 1. Fetch user's profile to get domain_id
  final profile = await _client
      .from('profiles')
      .select('domain_id')
      .eq('id', userId)
      .single();

  final domainId = profile['domain_id'];

  // 2. Insert post with domain_id
  final response = await _client
      .from('posts')
      .insert({
        'author_id': userId,
        'content': content,
        'domain_id': domainId,  // ← Manually set
      })
      .select()
      .single();

  return response;
}
```

**Why we DON'T do this:**

- ❌ Extra database query (slower)
- ❌ More code to maintain
- ❌ Potential for bugs (what if profile fetch fails?)
- ✅ Database trigger is faster and more reliable

---

## 🚀 Why This Approach is Better

### 1. **Single Source of Truth**

The database trigger ensures domain_id is ALWAYS set correctly, even if:

- Someone uses a different client (web, mobile, API)
- A developer forgets to set it manually
- An attacker tries to bypass the app

### 2. **Performance**

- No extra query to fetch user's domain_id
- Trigger executes in microseconds
- One database round-trip instead of two

### 3. **Security**

- Impossible to set wrong domain_id
- RLS validates the trigger's output
- Defense in depth

### 4. **Simplicity**

- Flutter code is cleaner (only 2 fields to insert)
- Less room for bugs
- Easier to maintain

---

## 📝 Summary

### ✅ What You Have

1. **`SupabaseService.createPost()`** - Simple function that only needs content
2. **Database trigger** - Automatically sets domain_id from author's profile
3. **RLS policy** - Validates domain_id matches user's domain
4. **CreatePostDialog** - Beautiful UI for creating posts
5. **Error handling** - Comprehensive try-catch with user feedback

### 🔑 Key Insight

**You DON'T need to manually fetch the user's domain_id!** The database trigger does it automatically. This is:

- ✅ Faster (one query instead of two)
- ✅ Safer (impossible to set wrong domain)
- ✅ Simpler (less code to maintain)

### 🎯 The Function You Asked For

```dart
// This is already implemented in lib/services/supabase_service.dart
static Future<Map<String, dynamic>> createPost({
  required String content,
}) async {
  final userId = _client.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  // Insert post - domain_id is AUTO-SET by database trigger!
  final response = await _client
      .from('posts')
      .insert({
        'author_id': userId,
        'content': content,
        // domain_id is automatically fetched and attached by trigger
      })
      .select()
      .single();

  return response;  // Returns post with domain_id populated
}
```

---

**The domain_id is automatically fetched from the user's profile and attached to the post by the database trigger. No manual fetching required! 🎉**
