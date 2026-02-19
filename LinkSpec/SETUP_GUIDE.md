# LinkSpec - Quick Setup Guide

## ⚡ 5-Minute Setup

### Step 1: Supabase Setup (2 minutes)

1. **Create Supabase Project**
   - Go to [supabase.com](https://supabase.com)
   - Click "New Project"
   - Choose organization and project name
   - Wait for provisioning (~1 minute)

2. **Run Database Schema**
   - Go to SQL Editor in Supabase dashboard
   - Copy contents from `../linkspec/supabase_schema.sql`
   - Paste and click "Run"
   - Verify tables created: profiles, posts, likes, connections

3. **Get Credentials**
   - Go to Project Settings → API
   - Copy "Project URL"
   - Copy "anon/public" key

### Step 2: Configure Flutter App (1 minute)

1. **Update Supabase Config**

   ```dart
   // lib/config/supabase_config.dart
   static const String supabaseUrl = 'https://xxxxx.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key-here';
   ```

2. **Install Dependencies**
   ```bash
   cd C:\Users\chkis\.gemini\antigravity\scratch\linkspec_app
   flutter pub get
   ```

### Step 3: Run the App (2 minutes)

1. **Connect Device/Emulator**
   - Start Android Emulator, or
   - Connect physical device via USB

2. **Run App**

   ```bash
   flutter run
   ```

3. **Test Flow**
   - App opens to splash screen
   - Redirects to login
   - Sign up with email/password
   - Select domain
   - View home feed

## ✅ Verification Checklist

- [ ] Supabase project created
- [ ] SQL schema executed successfully
- [ ] All 4 tables visible in Supabase Table Editor
- [ ] RLS enabled on all tables
- [ ] Supabase credentials copied to `supabase_config.dart`
- [ ] `flutter pub get` completed without errors
- [ ] App runs on device/emulator
- [ ] Can sign up with email
- [ ] Can select domain
- [ ] Can create post
- [ ] Can like/unlike posts

## 🎯 Test Scenarios

### Test 1: Domain Isolation

1. Create User A with "Medical" domain
2. Create Post as User A
3. Sign out
4. Create User B with "IT/Software" domain
5. **Expected**: User B cannot see User A's post ✅

### Test 2: Like Functionality

1. Sign in as User A
2. Create a post
3. Like the post
4. **Expected**: Like count increases to 1 ✅
5. Unlike the post
6. **Expected**: Like count decreases to 0 ✅

### Test 3: Delete Post

1. Sign in as User A
2. Create a post
3. Click delete icon
4. Confirm deletion
5. **Expected**: Post removed from feed ✅

## 🐛 Common Issues

### Issue: "Invalid API key"

**Solution**: Double-check you copied the **anon/public** key, not the service role key

### Issue: "Row Level Security policy violation"

**Solution**:

- Ensure RLS policies were created correctly
- Check that user has a profile with domain_id set
- Verify domain_id matches between user and post

### Issue: "No posts showing"

**Solution**:

- Create a post first
- Ensure you're signed in
- Check that profile has domain_id set
- Verify posts exist in your domain in Supabase Table Editor

### Issue: Build errors

**Solution**:

```bash
flutter clean
flutter pub get
flutter run
```

## 📱 Platform-Specific Setup

### Android

- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- No additional setup required

### iOS

- Minimum iOS: 12.0
- Requires Xcode 14+
- Run `pod install` in ios/ directory if needed

### Web

- Enable web support: `flutter config --enable-web`
- Run: `flutter run -d chrome`

## 🔧 Development Tools

### Recommended VS Code Extensions

- Flutter
- Dart
- Supabase Snippets
- Error Lens
- GitLens

### Useful Commands

```bash
# Hot reload
r

# Hot restart
R

# Open DevTools
d

# Quit
q

# Run with specific device
flutter run -d <device-id>

# List devices
flutter devices

# Check for issues
flutter doctor

# Analyze code
flutter analyze
```

## 📚 Next Steps

After successful setup:

1. **Explore the Code**
   - Read `PROJECT_STRUCTURE.md` for file organization
   - Check `lib/services/supabase_service.dart` for API methods
   - Review `lib/models/` for data structures

2. **Customize**
   - Add more domains in `app_constants.dart`
   - Customize theme in `main.dart`
   - Add your logo/branding

3. **Extend Features**
   - Implement user profiles
   - Add comments system
   - Enable image uploads
   - Add push notifications

## 🎓 Learning Resources

- [Flutter Cookbook](https://docs.flutter.dev/cookbook)
- [Supabase Flutter Tutorial](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Riverpod Documentation](https://riverpod.dev/docs/introduction/getting_started)
- [Material Design 3](https://m3.material.io)

## 💡 Pro Tips

1. **Use Hot Reload**: Press `r` in terminal for instant UI updates
2. **Check Supabase Logs**: Real-time logs in Supabase dashboard help debug
3. **Test RLS Policies**: Use SQL Editor with different auth contexts
4. **Use DevTools**: Press `d` to open Flutter DevTools for debugging

---

**Setup Time**: ~5 minutes
**Difficulty**: Beginner-friendly
**Support**: Check README.md for detailed documentation

🚀 **You're ready to build!**
