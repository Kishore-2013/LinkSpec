# LinkSpec Flutter Project - File Structure

## 📁 Complete File Tree

```
linkspec_app/
│
├── lib/
│   │
│   ├── config/                          # Configuration files
│   │   ├── app_constants.dart           # App-wide constants (domains, colors, limits)
│   │   └── supabase_config.dart         # Supabase credentials
│   │
│   ├── models/                          # Data models
│   │   ├── user_profile.dart            # UserProfile model with JSON serialization
│   │   └── post.dart                    # Post model with JSON serialization
│   │
│   ├── screens/                         # Full-page screens
│   │   ├── splash_screen.dart           # Initial loading & routing logic
│   │   ├── login_screen.dart            # Email/password authentication
│   │   ├── domain_selection_screen.dart # Onboarding domain selection
│   │   └── home_screen.dart             # Main feed with posts
│   │
│   ├── services/                        # Business logic & API calls
│   │   └── supabase_service.dart        # Supabase API wrapper (CRUD operations)
│   │
│   ├── widgets/                         # Reusable UI components
│   │   ├── post_card.dart               # Individual post display
│   │   └── create_post_dialog.dart      # Create post modal
│   │
│   ├── providers/                       # Riverpod providers (Phase 2)
│   │   └── (to be created)
│   │
│   ├── utils/                           # Utility functions (Phase 2)
│   │   └── (to be created)
│   │
│   └── main.dart                        # App entry point
│
├── android/                             # Android platform code
├── ios/                                 # iOS platform code
├── linux/                               # Linux platform code
├── macos/                               # macOS platform code
├── web/                                 # Web platform code
├── windows/                             # Windows platform code
├── test/                                # Unit & widget tests
│
├── pubspec.yaml                         # Dependencies & assets
├── pubspec.lock                         # Locked dependency versions
├── analysis_options.yaml                # Linter rules
├── README.md                            # Project documentation
└── .gitignore                           # Git ignore rules
```

## 📄 File Descriptions

### Configuration (`lib/config/`)

#### `app_constants.dart`

- Domain list and configuration
- Domain icons and colors mapping
- Validation constants (name length, bio length, etc.)
- UI constants (padding, radius, animation duration)

#### `supabase_config.dart`

- Supabase project URL
- Supabase anon key
- Realtime configuration
- Pagination settings

### Models (`lib/models/`)

#### `user_profile.dart`

```dart
class UserProfile {
  final String id;
  final String fullName;
  final String domainId;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### `post.dart`

```dart
class Post {
  final String id;
  final String authorId;
  final String domainId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? authorName;
  final String? authorAvatar;
  final int likeCount;
}
```

### Screens (`lib/screens/`)

#### `splash_screen.dart`

- Animated logo and branding
- Checks authentication state
- Routes to login, domain selection, or home

#### `login_screen.dart`

- Email/password sign in
- Email/password sign up
- Toggle between sign in/sign up modes
- Form validation

#### `domain_selection_screen.dart`

- Visual domain cards
- Full name input
- Optional bio input
- Creates profile in Supabase
- Routes to home after completion

#### `home_screen.dart`

- Displays feed of posts (domain-filtered)
- Infinite scroll pagination
- Pull-to-refresh
- Create post FAB
- Sign out option

### Services (`lib/services/`)

#### `supabase_service.dart`

**Profile Operations:**

- `saveDomainSelection()` - Create user profile
- `updateProfile()` - Update profile fields
- `getCurrentUserProfile()` - Get current user's profile
- `getProfilesInSameDomain()` - Search users in domain

**Post Operations:**

- `createPost()` - Create new post
- `getPosts()` - Get feed posts (paginated)
- `getPostsByUser()` - Get user's posts
- `updatePost()` - Edit post content
- `deletePost()` - Delete post

**Like Operations:**

- `likePost()` - Like a post
- `unlikePost()` - Remove like
- `hasLikedPost()` - Check like status

**Connection Operations:**

- `followUser()` - Follow a user
- `unfollowUser()` - Unfollow a user
- `isFollowing()` - Check follow status
- `getFollowers()` - Get followers list
- `getFollowing()` - Get following list
- `getConnectionCounts()` - Get follower/following counts

**Realtime:**

- `subscribeToNewPosts()` - Listen for new posts
- `subscribeToPostLikes()` - Listen for like changes

### Widgets (`lib/widgets/`)

#### `post_card.dart`

- Displays post content
- Shows author info and avatar
- Like/unlike button with count
- Delete button (for own posts)
- Relative timestamp

#### `create_post_dialog.dart`

- Text input for post content
- Character counter
- Form validation
- Loading state
- Success/error handling

### Main (`lib/main.dart`)

- Initializes Supabase
- Sets up Riverpod
- Configures Material theme
- Defines app routes
- Starts with SplashScreen

## 🎨 Theme Configuration

### Colors

- Primary: Deep Purple (`Colors.deepPurple`)
- Domain-specific colors in `AppConstants.domainColors`

### Typography

- Material Design 3 default typography
- Custom font weights for emphasis

### Components

- Rounded corners (12px radius)
- Elevated cards with shadows
- Filled input fields
- Consistent padding (16px)

## 🔄 Data Flow

```
User Action
    ↓
Screen/Widget
    ↓
Service Layer (supabase_service.dart)
    ↓
Supabase Client
    ↓
PostgreSQL Database (with RLS)
    ↓
Response
    ↓
Model (JSON → Dart object)
    ↓
State Update
    ↓
UI Rebuild
```

## 🚦 Navigation Flow

```
App Start
    ↓
SplashScreen
    ↓
Check Auth State
    ├─ Not Authenticated → LoginScreen
    │                          ↓
    │                      Sign Up/Sign In
    │                          ↓
    │                   DomainSelectionScreen
    │                          ↓
    └─ Authenticated ──────→ HomeScreen
                               ↓
                          (Main App)
```

## 📝 Next Steps

### Phase 2 Features to Add:

1. **Providers** (`lib/providers/`)
   - `auth_provider.dart` - Auth state management
   - `profile_provider.dart` - User profile state
   - `posts_provider.dart` - Posts feed state
   - `likes_provider.dart` - Liked posts state

2. **Additional Screens**
   - `profile_screen.dart` - View/edit profile
   - `user_profile_screen.dart` - View other users
   - `search_screen.dart` - Search users
   - `connections_screen.dart` - Followers/following

3. **Additional Widgets**
   - `user_card.dart` - User list item
   - `comment_card.dart` - Comment display
   - `loading_shimmer.dart` - Skeleton loaders

4. **Utils**
   - `validators.dart` - Form validation helpers
   - `formatters.dart` - Text formatting utilities
   - `image_helper.dart` - Image upload/compression

---

**Current Status:** Phase 1 Complete ✅
**Next Milestone:** User Profiles & Connections
