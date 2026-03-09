import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Use path URL strategy on web to remove the '#' from URLs.
// Conditional import: picks url_strategy_web.dart on Web, stub on mobile/desktop.
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
import 'screens/verification_screen.dart';
import 'screens/email_sender_screen.dart';
import 'providers/theme_provider.dart';
import 'api/session_cache.dart';
// Conditional import: picks web_lifecycle.dart on Web, stub on mobile/desktop.
import 'api/web_lifecycle_stub.dart'
    if (dart.library.html) 'api/web_lifecycle.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Remove the '#' from web URLs (path strategy).
  // On mobile, this resolves to a no-op stub at compile time.
  setPathUrlStrategy();


  // Ensure .env is loaded if present (fallback to dart-defines otherwise)
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




  // Register the beforeunload / lifecycle hook.

  // WebLifecycleHelper is a no-op stub on mobile; uses dart:html on Web.
  _registerWebUnloadListener();

  runApp(const ProviderScope(child: LinkSpecApp()));
}

/// Registers a `beforeunload` JS handler (Web) or no-op (mobile).
/// Uses conditional imports to keep dart:html out of the mobile build.
void _registerWebUnloadListener() {
  WebLifecycleHelper.register();
}

class LinkSpecApp extends ConsumerWidget {
  const LinkSpecApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'LinkSpec',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0066CC),
          onPrimary: Colors.white,
          secondary: const Color(0xFF0066CC),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1C1C1E),
          // 'background' and 'onBackground' are deprecated in favor of 'surface' 
          // but kept here as aliases if your custom code still references them.
          error: Colors.redAccent,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Color(0x0F000000),
          iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
          titleTextStyle: TextStyle(color: Color(0xFF1C1C1E), fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        // FIX: Changed CardTheme to CardThemeData to match Flutter 3.41 requirements
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA), thickness: 0.5),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/domain-selection': (context) => const DomainSelectionScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/groups': (context) => const GroupsScreen(),
        '/events': (context) => const EventsScreen(),
        '/search': (context) => const SearchScreen(),
        '/saved-items': (context) => const SavedItemsScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return VerificationScreen(
            email: args?['email'] ?? '',
            password: args?['password'],
            fullName: args?['fullName'],
            isSignUp: args?['isSignUp'] ?? false,
          );
        },
        '/email-sender': (context) => const EmailSenderScreen(),
      },
    );
  }
}
