# LinkSpec - Quick Start Guide 🚀

## ✅ What You Have

Your LinkSpec project is **fully scaffolded** with:

- ✅ Complete database schema with domain-gating RLS policies
- ✅ Flutter app structure with Riverpod state management
- ✅ Domain selection screen with beautiful UI
- ✅ Supabase service layer with all CRUD operations
- ✅ Authentication flow (Splash → Login → Domain Selection → Home)

---

## 🎯 Setup Steps (15 minutes)

### **Step 1: Create Supabase Project** (5 min)

1. Go to [https://supabase.com](https://supabase.com)
2. Click **"New Project"**
3. Fill in:
   - **Name**: LinkSpec
   - **Database Password**: (choose a strong password)
   - **Region**: (choose closest to you)
4. Wait for project to initialize (~2 minutes)

### **Step 2: Get Your Credentials** (1 min)

1. In Supabase Dashboard, go to **Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://xxxxx.supabase.co`)
   - **anon/public key** (starts with `eyJhbGc...`)

### **Step 3: Configure Flutter App** (1 min)

1. Open `lib/config/supabase_config.dart`
2. Replace the placeholder values:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGc...YOUR_ANON_KEY';

  // ... rest stays the same
}
```

### **Step 4: Set Up Database** (3 min)

1. In Supabase Dashboard, go to **SQL Editor**
2. Click **"New Query"**
3. Copy the **entire contents** of `supabase_schema.sql`
4. Paste into the SQL editor
5. Click **"Run"** (or press Ctrl+Enter)
6. ✅ You should see "Success. No rows returned"

**What this does:**

- Creates 4 tables: `profiles`, `posts`, `likes`, `connections`
- Sets up Row Level Security (RLS) policies for domain-gating
- Creates database triggers for auto-setting domain IDs
- Adds indexes for performance

### **Step 5: Enable Email Auth** (2 min)

1. In Supabase Dashboard, go to **Authentication** → **Providers**
2. Make sure **Email** is enabled
3. (Optional) Configure email templates under **Email Templates**

### **Step 6: Install Flutter Dependencies** (2 min)

```bash
cd c:\ApplyWizz\LinkSpec
flutter pub get
```

### **Step 7: Run the App** (1 min)

```bash
# For Android/iOS emulator
flutter run

# For Chrome (web)
flutter run -d chrome

# For Windows
flutter run -d windows
```

---

## 🧪 Testing the Domain Gate

### **Test 1: Create Two Users in Different Domains**

1. **User A**: Sign up → Select **"Medical"** domain
2. **User B**: Sign up (different email) → Select **"IT/Software"** domain

### **Test 2: Verify Domain Isolation**

1. **User A** creates a post: "Looking for cardiology advice"
2. **User B** logs in and checks feed
3. ✅ **Expected**: User B does NOT see User A's post
4. ❌ **If User B sees it**: RLS policies not working (check SQL execution)

### **Test 3: Verify Same-Domain Visibility**

1. **User C**: Sign up → Select **"Medical"** domain (same as User A)
2. **User C** checks feed
3. ✅ **Expected**: User C DOES see User A's post

---

## 📱 User Flow

```
1. App Launch
   ↓
2. Splash Screen (checks auth state)
   ↓
3a. Not logged in → Login Screen
   ↓
4. Sign Up / Sign In
   ↓
5. Domain Selection Screen ← MANDATORY
   ↓
6. Home Screen (domain-filtered feed)
```

---

## 🔧 Troubleshooting

### **Problem: "User not authenticated" error**

**Solution**: Make sure you're signed in. Check:

```dart
final user = Supabase.instance.client.auth.currentUser;
print('Current user: ${user?.email}');
```

### **Problem: Can't insert profile**

**Solution**: Check RLS policies are enabled:

```sql
-- In Supabase SQL Editor
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';
```

All tables should have `rowsecurity = true`.

### **Problem: Posts from other domains are visible**

**Solution**:

1. Verify RLS policies were created (check SQL Editor → "Policies" tab)
2. Re-run the schema SQL
3. Check that `domain_id` is correctly set on posts

### **Problem: Flutter build errors**

**Solution**:

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🎨 Customization Ideas

### **Add More Domains**

1. Update `supabase_schema.sql`:

```sql
CHECK (domain_id IN ('Medical', 'IT/Software', 'Civil Engineering', 'Law', 'Finance', 'Education'))
```

2. Update `domain_selection_screen.dart`:

```dart
final List<String> _domains = [
  'Medical',
  'IT/Software',
  'Civil Engineering',
  'Law',
  'Finance',
  'Education',
];
```

3. Re-run the SQL schema (drop tables first if needed)

### **Add Profile Pictures**

Use Supabase Storage:

```dart
// Upload avatar
final file = File('path/to/image.jpg');
final path = '${user.id}/avatar.jpg';
await Supabase.instance.client.storage
    .from('avatars')
    .upload(path, file);

// Get public URL
final url = Supabase.instance.client.storage
    .from('avatars')
    .getPublicUrl(path);

// Update profile
await SupabaseService.updateProfile(avatarUrl: url);
```

### **Add Comments**

Create a new table:

```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS: Only users in same domain as post can comment
CREATE POLICY "Users can comment on posts in same domain"
  ON comments
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id AND
    EXISTS (
      SELECT 1 FROM posts p
      INNER JOIN profiles pr ON pr.id = auth.uid()
      WHERE p.id = post_id AND p.domain_id = pr.domain_id
    )
  );
```

---

## 📚 Next Features to Build

### **Phase 2: Enhanced Feed**

- [ ] Pull-to-refresh
- [ ] Infinite scroll pagination
- [ ] Post images/videos
- [ ] Search posts by content

### **Phase 3: Social Features**

- [ ] User profiles with follower/following counts
- [ ] Direct messaging (domain-gated)
- [ ] Notifications
- [ ] Hashtags (domain-specific)

### **Phase 4: Professional Features**

- [ ] Job postings (domain-specific)
- [ ] Events/Webinars
- [ ] Skill endorsements
- [ ] Professional certifications

---

## 🔐 Security Checklist

- ✅ RLS enabled on all tables
- ✅ Domain gate enforced at database level
- ✅ Foreign key constraints in place
- ✅ Unique constraints prevent duplicates
- ✅ Check constraints validate domain values
- ✅ Cascade deletes clean up orphaned data
- ✅ Triggers auto-set domain IDs
- ✅ JWT tokens managed by Supabase Auth

---

## 📖 Documentation Files

- **ARCHITECTURE.md**: System design and data flow diagrams
- **PROJECT_STRUCTURE.md**: File organization
- **SUPABASE_REFERENCE.md**: Database schema details
- **SETUP_GUIDE.md**: Detailed setup instructions

---

## 🆘 Need Help?

1. Check Supabase logs: Dashboard → Logs
2. Check Flutter console for errors
3. Verify RLS policies in Supabase Dashboard → Authentication → Policies
4. Test SQL queries directly in SQL Editor

---

**You're ready to build! 🎉**

Run `flutter run` and start testing your domain-gated social network!
