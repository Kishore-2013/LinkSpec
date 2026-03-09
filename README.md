# LinkSpec - Flutter App

A domain-gated professional networking mobile application built with Flutter and Supabase.

## 📱 Project Structure

````
linkspec_app/
├── lib/
│   ├── config/
# LinkSpec - Domain-Gated Vertical Social Network

A professional networking application built with Flutter and Supabase, featuring strict domain-based isolation.

## 🎯 Core Concept

LinkSpec is a "Vertical Social Network" where users are segregated by professional domains (Medical, IT/Software, Civil Engineering, Law). Users can **ONLY** interact with others in their exact domain - enforced at the database level through Row Level Security (RLS).

## 🏗️ Tech Stack

- **Frontend**: Flutter with Riverpod state management
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Navigation**: Named routes

## ✨ Features

### ✅ Phase 1 - COMPLETE
- ✅ User authentication (email/password)
- ✅ Mandatory domain selection during onboarding
- ✅ Domain-gated feed (users only see posts from their domain)
- ✅ Create, read, update, delete posts
- ✅ Like/unlike posts (domain-restricted)
- ✅ Follow/unfollow users (domain-restricted)
- ✅ Real-time updates for new posts and likes
- ✅ Complete Supabase service layer
- ✅ Beautiful domain selection UI

### 🚧 Phase 2 - Next Steps
- [ ] Connect Supabase project (add credentials)
- [ ] Run database schema in Supabase
- [ ] Test authentication flow
- [ ] Test domain isolation
- [ ] Add user profile screen
- [ ] Add search functionality
- [ ] Add post images

### 📋 Future Features
- [ ] Direct messaging (domain-gated)
- [ ] Hashtags and mentions
- [ ] Notifications
- [ ] Job postings
- [ ] Professional certifications

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- A Supabase account (free tier works)

### Setup (15 minutes)

1. **Install dependencies**
   ```bash
   flutter pub get
````

2. **Set up Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Copy your project URL and anon key
   - Update `lib/config/supabase_config.dart` with your credentials

3. **Run the database schema**
   - Open Supabase Dashboard → SQL Editor
   - Copy entire contents of `supabase_schema.sql`
   - Execute the SQL

4. **Run the app**
   ```bash
   flutter run
   ```

📖 **Detailed setup guide**: See [QUICK_START.md](QUICK_START.md)

## 📁 Project Structure

```
lib/
├── config/
│   └── supabase_config.dart      # ⚠️ ADD YOUR CREDENTIALS HERE
├── models/
│   ├── profile.dart               # User profile model
│   └── post.dart                  # Post model
├── screens/
│   ├── splash_screen.dart         # Initial loading screen
│   ├── login_screen.dart          # Authentication
│   ├── domain_selection_screen.dart  # Domain onboarding ✨
│   └── home_screen.dart           # Main feed
├── services/
│   └── supabase_service.dart      # Complete database operations ✅
├── widgets/
│   ├── post_card.dart             # Post display widget
│   └── user_card.dart             # User profile widget
└── main.dart                      # App entry point

supabase_schema.sql                # Database schema with RLS ✅
```

## 🔐 Domain Gate Architecture

The domain gate is enforced at **three levels**:

1.  **Database Level (Primary)**: PostgreSQL RLS policies ✅
2.  **Service Layer**: Supabase service methods ✅
3.  **UI Layer**: Flutter widgets ✅

### Example: Post Creation Flow

```
User (Medical Domain)
  ↓
Flutter: SupabaseService.createPost("Medical breakthrough!")
  ↓
Supabase: INSERT INTO posts (author_id, content)
  ↓
Database Trigger: Auto-set domain_id = 'Medical'
  ↓
RLS Policy: Verify domain_id matches user's domain
  ↓
✅ Post saved and visible only to Medical domain users
```

### Example: Cross-Domain Prevention

```
User A (Medical) creates post
  ↓
User B (IT/Software) tries to like it
  ↓
RLS Policy: Check post.domain_id == user.domain_id
  ↓
❌ REJECTED - Domain mismatch (403 Forbidden)
```

## 📊 Database Schema

### Tables

1.  **profiles**: User profiles with mandatory domain_id
2.  **posts**: User-generated content (domain auto-inherited)
3.  **likes**: Post likes (domain-validated)
4.  **connections**: Follow relationships (domain-restricted)

### Key RLS Policies

- ✅ Users can only view profiles in their domain
- ✅ Users can only see posts in their domain
- ✅ Users can only like posts in their domain
- ✅ Users can only follow users in their domain
- ✅ Domain cannot be changed after profile creation

📖 **Full schema details**: See [ARCHITECTURE.md](ARCHITECTURE.md)

## 🧪 Testing the Domain Gate

### Test Scenario 1: Cross-Domain Isolation

1.  Create User A → Select **Medical** domain
2.  User A creates post: "Looking for cardiology advice"
3.  Create User B → Select **IT/Software** domain
4.  User B checks feed
5.  ✅ **Expected**: User B does NOT see User A's post

### Test Scenario 2: Same-Domain Visibility

1.  Create User C → Select **Medical** domain
2.  User C checks feed
3.  ✅ **Expected**: User C DOES see User A's post

### Test Scenario 3: Like Restriction

1.  User B tries to like User A's post (via API)
2.  ✅ **Expected**: 403 Forbidden error (RLS blocks it)

## 📚 Documentation

- **[QUICK_START.md](QUICK_START.md)** ⭐ - Start here! Step-by-step setup
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design and data flow diagrams
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** - Code organization
- **[SUPABASE_REFERENCE.md](SUPABASE_REFERENCE.md)** - Database schema reference
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Detailed configuration guide

## 🎨 Screenshots

### Domain Selection Screen

Beautiful, color-coded domain cards with icons:

- 🏥 Medical (Red)
- 💻 IT/Software (Blue)
- 🏗️ Civil Engineering (Orange)
- ⚖️ Law (Purple)

## 🛠️ Development

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

## 🔧 Customization

### Adding New Domains

1.  Update `supabase_schema.sql`:

    ```sql
    CHECK (domain_id IN ('Medical', 'IT/Software', 'Civil Engineering', 'Law', 'Finance'))
    ```

2.  Update `lib/screens/domain_selection_screen.dart`:

    ```dart
    final List<String> _domains = [
      'Medical',
      'IT/Software',
      'Civil Engineering',
      'Law',
      'Finance',  // New domain
    ];
    ```

3.  Re-run the schema SQL in Supabase

## 🆘 Troubleshooting

### "User not authenticated" error

```dart
// Check auth state
final user = Supabase.instance.client.auth.currentUser;
print('Current user: ${user?.email}');
```

### Posts from other domains are visible

1.  Verify RLS is enabled:
    ```sql
    SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public';
    ```
2.  Check RLS policies exist in Supabase Dashboard → Authentication → Policies
3.  Re-run `supabase_schema.sql`

### Build errors

```bash
flutter clean
flutter pub get
flutter run
```

### Supabase connection issues

- Verify credentials in `lib/config/supabase_config.dart`
- Check internet connection
- Verify Supabase project is active

## 📝 Code Quality

- ✅ Clean, modular Dart code
- ✅ Comprehensive error handling
- ✅ Loading states for async operations
- ✅ Form validation
- ✅ Proper state management with Riverpod
- ✅ Responsive UI design
- ✅ Material 3 design system

## 🔒 Security Features

- ✅ Database-level domain enforcement (RLS)
- ✅ Automatic domain inheritance for posts
- ✅ Unique constraints prevent duplicates
- ✅ Cascade deletes clean up orphaned data
- ✅ Check constraints validate domain values
- ✅ Foreign keys maintain referential integrity
- ✅ JWT token-based authentication

## 🤝 Contributing

This is a portfolio/educational project. Suggestions welcome!

## 📄 License

Educational and portfolio use.

---

## ⚡ Current Status

**✅ Phase 1 Complete** - All core infrastructure is ready!

**Next Step**: Add your Supabase credentials and run the schema SQL.

See [QUICK_START.md](QUICK_START.md) for detailed instructions.

---

**Built with ❤️ using Flutter and Supabase**

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Supabase Flutter Docs](https://supabase.com/docs/reference/dart/introduction)
- [Riverpod Documentation](https://riverpod.dev)
- [Material Design 3](https://m3.material.io)

## 🤝 Contributing

This is a private project. For questions or issues, contact the development team.

## 📄 License

Proprietary - All rights reserved

---

**Built with ❤️ using Flutter and Supabase**
