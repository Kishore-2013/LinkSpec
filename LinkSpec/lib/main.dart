import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: LinkSpecApp()));
}

class LinkSpecApp extends ConsumerWidget {
  const LinkSpecApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'LinkSpec',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
          background: const Color(0xFFF5F5F7),
          onBackground: const Color(0xFF1C1C1E),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Color(0x0F000000),
          iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
          titleTextStyle: TextStyle(color: Color(0xFF1C1C1E), fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE5E5EA), thickness: 0.5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0A84FF),
          onPrimary: Colors.white,
          secondary: const Color(0xFF0A84FF),
          onSecondary: Colors.white,
          surface: const Color(0xFF1C1C1E),
          onSurface: Colors.white,
          background: const Color(0xFF000000),
          onBackground: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1C1C1E),
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.transparent,
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF38383A), thickness: 0.5),
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
            providerType: args?['providerType'] ?? 'gmail',
            password: args?['password'],
            fullName: args?['fullName'],
            isSignUp: args?['isSignUp'] ?? false,
          );
        },
      },
    );
  }
}
