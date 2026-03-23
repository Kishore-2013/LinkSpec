import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../services/supabase_service.dart';
import '../services/linkspec_notify.dart';
import '../providers/domain_provider.dart';
import '../screens/login_screen.dart';
import '../screens/domain_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/reset_password_screen.dart';
import '../providers/supabase_auth_provider.dart';
import 'main_layout.dart';

/// Entry point wrapper that handles fast domain-based routing.
/// Prevents redundant delays and ensures users are routed correctly.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseAuthAsync = ref.watch(supabaseAuthStateProvider);

    return supabaseAuthAsync.when(
      data: (supabaseState) {
        final session = sb.Supabase.instance.client.auth.currentSession;
        
        if (supabaseState.event == sb.AuthChangeEvent.passwordRecovery) {
          return const LinkSpecAuthScreen();
        }

        if (session == null) {
          return const LoginScreen();
        }

        return _handleAuthenticatedState(context, ref);
      },
      loading: () => _buildLoadingScreen(),
      error: (e, st) => const LoginScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066CC)),
        ),
      ),
    );
  }

  Widget _handleAuthenticatedState(BuildContext context, WidgetRef ref) {
    // FETCH PROFILE: With Timeout and Error Catch to prevent infinite loading.
    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.getCurrentUserProfile()
          .timeout(const Duration(seconds: 8)),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (profileSnapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            LinkSpecNotify.show(context, LinkSpecNotify.mapError('session_timeout'), LinkSpecNotifyType.info);
          });
          return const LoginScreen();
        }

        final profile = profileSnapshot.data;
        
        if (profile == null || profile['domain_id'] == null) {
          return const DomainSelectionScreen();
        }

        // Sync domain state immediately
        final profileDomain = profile['domain_id'] as String?;
        if (profileDomain != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(currentDomainProvider.notifier).state = profileDomain;
          });
        }

        return const MainLayout(child: HomeScreen());
      },
    );
  }
}

