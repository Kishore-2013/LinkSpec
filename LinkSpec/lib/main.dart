import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/domain_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/events_screen.dart';
import 'screens/search_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        fontFamily: 'Roboto', // Modern, clean font
        scaffoldBackgroundColor: const Color(0xFFC0DFFF),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF0066CC),
          secondary: Colors.blueAccent,
          surface: const Color(0xFFE3F2FF),
          background: const Color(0xFFC0DFFF),
          onSurface: const Color(0xFF003366),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFFE3F2FF),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
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
      },
    );
  }
}
