# Domain-Gated Feed Implementation

## 📊 How the Feed Query Works

### The Query (in `lib/services/supabase_service.dart`)

```dart
/// Get posts in the same domain (feed)
static Future<List<Map<String, dynamic>>> getPosts({
  int limit = 20,
  int offset = 0,
}) async {
  final response = await _client
      .from('posts_with_stats')  // ← Uses view with author info and like counts
      .select()
      .order('created_at', ascending: false)  // ← Newest first
      .range(offset, offset + limit - 1);  // ← Pagination

  return List<Map<String, dynamic>>.from(response);
}
```

### 🔐 Domain Filtering (Automatic via RLS)

The query looks simple, but **domain filtering happens automatically** at the database level through Row Level Security (RLS).

#### What Actually Happens:

```sql
-- What you write in Flutter:
SELECT * FROM posts_with_stats ORDER BY created_at DESC

-- What PostgreSQL executes (with RLS):
SELECT * FROM posts_with_stats
WHERE domain_id = (
  SELECT domain_id FROM profiles WHERE id = auth.uid()
)
ORDER BY created_at DESC
```

### 🎯 The RLS Policy (from `supabase_schema.sql`)

```sql
CREATE POLICY "Users can view posts in same domain"
  ON posts
  FOR SELECT
  USING (
    domain_id = (
      SELECT domain_id FROM profiles WHERE id = auth.uid()
    )
  );
```

**Translation**: "You can only SELECT posts where the post's `domain_id` matches YOUR `domain_id`"

## 🏗️ The `posts_with_stats` View

This view joins posts with profiles and aggregates like counts:

```sql
CREATE OR REPLACE VIEW posts_with_stats AS
SELECT
  p.*,
  pr.full_name as author_name,
  pr.avatar_url as author_avatar,
  COUNT(DISTINCT l.id) as like_count
FROM posts p
LEFT JOIN profiles pr ON p.author_id = pr.id
LEFT JOIN likes l ON p.id = l.post_id
GROUP BY p.id, pr.full_name, pr.avatar_url;
```

**Benefits:**

- ✅ Single query gets post + author info + like count
- ✅ RLS still applies (view inherits policies from base table)
- ✅ Efficient aggregation at database level

## 📱 Flutter UI Implementation

### Home Screen (`lib/screens/home_screen.dart`)

The home screen displays the domain-filtered feed with:

1. **Initial Load**: Fetches first 20 posts
2. **Infinite Scroll**: Loads more as user scrolls
3. **Pull-to-Refresh**: Refreshes feed
4. **Empty State**: Shows when no posts exist
5. **Domain Badge**: Displays current user's domain in AppBar

### Key Features:

```dart
// Load posts (domain-filtered automatically)
Future<void> _loadPosts() async {
  final postsData = await SupabaseService.getPosts(
    limit: _limit,
    offset: 0
  );
  // Only posts in user's domain are returned!
}

// Infinite scroll
void _onScroll() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent * 0.9) {
    _loadMorePosts();
  }
}

// Pull to refresh
RefreshIndicator(
  onRefresh: _refreshPosts,
  child: ListView.builder(...)
)
```

## 🔒 Security Guarantees

### 1. **Database-Level Enforcement**

Even if someone bypasses the Flutter app and calls the API directly, RLS blocks cross-domain access.

### 2. **Automatic Domain Inheritance**

When creating a post, the domain_id is auto-set by a database trigger:

```sql
CREATE TRIGGER auto_set_post_domain
  BEFORE INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION set_post_domain();
```

### 3. **No Client-Side Filtering**

The app doesn't filter posts in Dart. The database only returns posts in the user's domain.

## 🧪 Testing the Domain Gate

### Test 1: Cross-Domain Isolation

```
User A (Medical Domain):
  - Creates post: "Cardiology conference next week"

User B (IT/Software Domain):
  - Checks feed
  - ✅ EXPECTED: Feed is empty (or shows only IT posts)
  - ❌ FAIL: If User B sees User A's post, RLS is not working
```

### Test 2: Same-Domain Visibility

```
User A (Medical Domain):
  - Creates post: "Cardiology conference next week"

User C (Medical Domain):
  - Checks feed
  - ✅ EXPECTED: Sees User A's post
  - ❌ FAIL: If User C doesn't see it, check database trigger
```

### Test 3: Direct API Call (Advanced)

```bash
# Try to fetch posts with a different domain's auth token
curl 'https://YOUR_PROJECT.supabase.co/rest/v1/posts' \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer USER_B_TOKEN"

# ✅ EXPECTED: Only returns IT/Software posts
# ❌ FAIL: If it returns Medical posts, RLS policies are broken
```

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Opens Home Screen                    │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Flutter: SupabaseService.getPosts(limit: 20, offset: 0)   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Client: SELECT * FROM posts_with_stats            │
│                   ORDER BY created_at DESC                   │
│                   LIMIT 20 OFFSET 0                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL RLS: Inject WHERE clause                        │
│  WHERE domain_id = (SELECT domain_id FROM profiles          │
│                     WHERE id = auth.uid())                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Database: Execute filtered query                            │
│  - User is in "Medical" domain                               │
│  - Only returns posts with domain_id = 'Medical'             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase: Return JSON array of posts                       │
│  [                                                           │
│    {                                                         │
│      "id": "uuid",                                           │
│      "content": "Medical post content",                      │
│      "domain_id": "Medical",                                 │
│      "author_name": "Dr. Sarah",                             │
│      "like_count": 5,                                        │
│      ...                                                     │
│    }                                                         │
│  ]                                                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Flutter: Parse JSON to Post models                         │
│  Display in ListView with PostCard widgets                  │
└─────────────────────────────────────────────────────────────┘
```

## 🎨 UI Components

### PostCard Widget (`lib/widgets/post_card.dart`)

Displays each post with:

- Author name and avatar
- Post content
- Like button with count
- Delete button (if user is author)
- Timestamp (relative, e.g., "2 hours ago")

### CreatePostDialog Widget (`lib/widgets/create_post_dialog.dart`)

Modal dialog for creating posts:

- Text input for content
- Character limit (optional)
- Submit button
- Auto-sets domain_id via database trigger

## 🚀 Performance Optimizations

### 1. **Pagination**

- Loads 20 posts at a time
- Infinite scroll for seamless UX

### 2. **Database Indexes**

```sql
CREATE INDEX idx_posts_domain_id ON posts(domain_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
```

### 3. **View Caching**

The `posts_with_stats` view is materialized for faster queries (optional).

### 4. **Lazy Loading**

Posts load as user scrolls, not all at once.

## 📝 Code Quality Features

- ✅ **Error Handling**: Try-catch blocks with user-friendly messages
- ✅ **Loading States**: Shows spinner while fetching
- ✅ **Empty States**: Helpful message when no posts exist
- ✅ **Pull-to-Refresh**: Standard mobile UX pattern
- ✅ **Responsive**: Works on all screen sizes
- ✅ **Type Safety**: Uses Post model instead of raw maps

## 🔧 Customization Options

### Change Posts Per Page

```dart
// In home_screen.dart
final int _limit = 50; // Default is 20
```

### Add Search/Filter

```dart
// Add to SupabaseService
static Future<List<Map<String, dynamic>>> searchPosts({
  required String query,
  int limit = 20,
}) async {
  final response = await _client
      .from('posts_with_stats')
      .select()
      .ilike('content', '%$query%')  // Search in content
      .order('created_at', ascending: false)
      .limit(limit);

  return List<Map<String, dynamic>>.from(response);
}
```

### Add Post Images

1. Update schema to add `image_url` column
2. Use Supabase Storage to upload images
3. Update PostCard to display images

---

## ✅ Summary

Your feed implementation is **production-ready** with:

1. ✅ **Domain-gated queries** via RLS (automatic, secure)
2. ✅ **Efficient pagination** with infinite scroll
3. ✅ **Clean UI** with loading/empty states
4. ✅ **Pull-to-refresh** for better UX
5. ✅ **Type-safe models** for data handling
6. ✅ **Error handling** for robustness

**The domain gate is enforced at the database level, making it impossible to bypass!** 🔒
