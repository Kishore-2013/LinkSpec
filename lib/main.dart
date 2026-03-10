import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// Use path URL strategy on web to remove the '#' from URLs.
import 'utils/url_strategy_stub.dart'
    if (dart.library.html) 'utils/url_strategy_web.dart';

import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/domain_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/events_screen.dart';
import 'screens/search_screen.dart';
import 'screens/saved_items_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'providers/theme_provider.dart';
import 'api/session_cache.dart';
import 'api/web_lifecycle_stub.dart'
    if (dart.library.html) 'api/web_lifecycle.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    debugPrint("Note: assets/.env not found, relying on environment variables/dart-defines.");
  }

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: kIsWeb ? WebSessionStorage() : const EmptyLocalStorage(),
    ),
  );

  WebLifecycleHelper.register();

  runApp(const ProviderScope(child: LinkSpecApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => AuthWrapper(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/login', // Alias for /auth to maintain compatibility if needed
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/otp-verify',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? (state.extra as String? ?? '');
        return OTPVerificationScreen(email: email);
      },
    ),
    GoRoute(
      path: '/domain-selection',
      builder: (context, state) => DomainSelectionScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/groups',
      builder: (context, state) => const GroupsScreen(),
    ),
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/saved-items',
      builder: (context, state) => const SavedItemsScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const LinkSpecAuthScreen(),
    ),
  ],
);

class LinkSpecApp extends ConsumerWidget {
  const LinkSpecApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'LinkSpec',
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0066CC),
          onPrimary: Colors.white,
          secondary: Color(0xFF0066CC),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF1C1C1E),
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Color(0x0F000000),
          iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1C1C1E), 
            fontSize: 18, 
            fontWeight: FontWeight.w700, 
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA), thickness: 0.5),
      ),
    );
  }
}
