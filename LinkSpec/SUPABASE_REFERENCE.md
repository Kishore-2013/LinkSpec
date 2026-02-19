# LinkSpec - Supabase Setup Quick Reference

## 🎯 Quick Start Checklist

- [ ] Create Supabase project
- [ ] Run `supabase_schema.sql` in SQL Editor
- [ ] Verify all 4 tables are created
- [ ] Verify RLS is enabled on all tables
- [ ] Copy Project URL and Anon Key
- [ ] Update Flutter `main.dart` with credentials
- [ ] Test authentication flow
- [ ] Test domain selection

## 📊 Database Tables Summary

| Table         | Purpose              | Key Fields                        | RLS Enforced    |
| ------------- | -------------------- | --------------------------------- | --------------- |
| `profiles`    | User profiles        | id, full_name, domain_id, bio     | ✅ Domain-gated |
| `posts`       | User posts           | id, author_id, domain_id, content | ✅ Domain-gated |
| `likes`       | Post likes           | id, post_id, user_id              | ✅ Domain-gated |
| `connections` | Follow relationships | follower_id, following_id         | ✅ Domain-gated |

## 🔒 RLS Policies Summary

### Profiles Table

```sql
-- SELECT: View profiles in same domain only
-- INSERT: Create own profile
-- UPDATE: Update own profile only
```

### Posts Table

```sql
-- SELECT: View posts in same domain only
-- INSERT: Create posts (domain auto-set)
-- UPDATE: Update own posts only
-- DELETE: Delete own posts only
```

### Likes Table

```sql
-- SELECT: View likes on posts in same domain
-- INSERT: Like posts in same domain only
-- DELETE: Unlike own likes only
```

### Connections Table

```sql
-- SELECT: View connections in same domain
-- INSERT: Follow users in same domain only
-- DELETE: Unfollow own connections only
```

## 🧪 Testing Queries

### Test 1: Verify Domain Isolation

```sql
-- As user in "Medical" domain
SELECT * FROM posts;
-- Should only return posts with domain_id = 'Medical'

-- Try to insert post with wrong domain
INSERT INTO posts (author_id, domain_id, content)
VALUES (auth.uid(), 'IT/Software', 'Test');
-- Should FAIL due to RLS policy
```

### Test 2: Verify Auto Domain Inheritance

```sql
-- Create post without specifying domain_id
INSERT INTO posts (author_id, content)
VALUES (auth.uid(), 'My first post!');
-- domain_id should be auto-set from user's profile
```

### Test 3: Verify Cross-Domain Prevention

```sql
-- As Medical user, try to like IT post
INSERT INTO likes (post_id, user_id)
VALUES ('some-it-post-id', auth.uid());
-- Should FAIL - post not in same domain
```

## 🔑 Supabase Service Methods

### Profile Operations

```dart
// Save domain selection (onboarding)
await SupabaseService.saveDomainSelection(
  fullName: 'John Doe',
  domainId: 'IT/Software',
  bio: 'Software Engineer',
);

// Get current user profile
final profile = await SupabaseService.getCurrentUserProfile();

// Update profile
await SupabaseService.updateProfile(
  fullName: 'John Smith',
  bio: 'Senior Software Engineer',
);
```

### Post Operations

```dart
// Create post
await SupabaseService.createPost(
  content: 'Hello LinkSpec!',
);

// Get feed (posts in same domain)
final posts = await SupabaseService.getPosts(limit: 20);

// Get user's posts
final myPosts = await SupabaseService.getPostsByUser(
  userId: currentUserId,
);

// Delete post
await SupabaseService.deletePost(postId);
```

### Like Operations

```dart
// Like a post
await SupabaseService.likePost(postId);

// Unlike a post
await SupabaseService.unlikePost(postId);

// Check if liked
final isLiked = await SupabaseService.hasLikedPost(postId);
```

### Connection Operations

```dart
// Follow user
await SupabaseService.followUser(userId);

// Unfollow user
await SupabaseService.unfollowUser(userId);

// Check if following
final isFollowing = await SupabaseService.isFollowing(userId);

// Get followers
final followers = await SupabaseService.getFollowers(
  userId: currentUserId,
);

// Get following
final following = await SupabaseService.getFollowing(
  userId: currentUserId,
);
```

### Realtime Subscriptions

```dart
// Subscribe to new posts
final channel = SupabaseService.subscribeToNewPosts(
  onNewPost: (post) {
    print('New post: ${post['content']}');
  },
);

// Unsubscribe when done
await channel.unsubscribe();
```

## 🎨 Domain Configuration

```dart
final domains = [
  'Medical',
  'IT/Software',
  'Civil Engineering',
  'Law',
];

final domainIcons = {
  'Medical': Icons.local_hospital,
  'IT/Software': Icons.computer,
  'Civil Engineering': Icons.engineering,
  'Law': Icons.gavel,
};

final domainColors = {
  'Medical': Colors.red,
  'IT/Software': Colors.blue,
  'Civil Engineering': Colors.orange,
  'Law': Colors.purple,
};
```

## 🚨 Common Errors & Solutions

### Error: "new row violates row-level security policy"

**Cause**: Trying to insert data that doesn't match your domain
**Solution**: Ensure domain_id matches your profile's domain_id

### Error: "duplicate key value violates unique constraint"

**Cause**: Trying to like a post twice or follow a user twice
**Solution**: Check if already liked/following before inserting

### Error: "User not authenticated"

**Cause**: No active session
**Solution**: Ensure user is logged in before calling Supabase methods

### Error: "null value in column 'domain_id'"

**Cause**: User profile doesn't have domain_id set
**Solution**: Ensure domain selection is completed during onboarding

## 📈 Performance Optimization

### Indexes Created

```sql
-- Profiles
CREATE INDEX idx_profiles_domain_id ON profiles(domain_id);

-- Posts
CREATE INDEX idx_posts_domain_id ON posts(domain_id);
CREATE INDEX idx_posts_author_id ON posts(author_id);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- Likes
CREATE INDEX idx_likes_post_id ON likes(post_id);
CREATE INDEX idx_likes_user_id ON likes(user_id);

-- Connections
CREATE INDEX idx_connections_follower_id ON connections(follower_id);
CREATE INDEX idx_connections_following_id ON connections(following_id);
```

### Query Optimization Tips

1. Use pagination (limit/offset) for large result sets
2. Use `posts_with_stats` view for feed (includes like counts)
3. Cache user profile locally to reduce queries
4. Use realtime subscriptions for live updates

## 🔄 Migration Guide (Adding New Domain)

1. **Update Database**:

```sql
-- Modify CHECK constraint
ALTER TABLE profiles DROP CONSTRAINT profiles_domain_id_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_domain_id_check
  CHECK (domain_id IN ('Medical', 'IT/Software', 'Civil Engineering', 'Law', 'Finance'));
```

2. **Update Flutter**:

```dart
// Add to domain list
final List<String> _domains = [
  'Medical',
  'IT/Software',
  'Civil Engineering',
  'Law',
  'Finance', // New domain
];

// Add icon and color
_domainIcons['Finance'] = Icons.account_balance;
_domainColors['Finance'] = Colors.green;
```

## 📞 Support

For issues or questions:

1. Check Supabase logs in dashboard
2. Review RLS policies in Authentication → Policies
3. Test queries in SQL Editor
4. Check Flutter debug console for errors

---

**Happy Building! 🚀**
