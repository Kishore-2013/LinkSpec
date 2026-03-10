import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../services/supabase_service.dart';
import '../providers/domain_provider.dart';
import '../screens/login_screen.dart';
import '../screens/domain_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/reset_password_screen.dart';

/// Entry point wrapper that handles fast domain-based routing.
/// Prevents redundant delays and ensures users are routed correctly
/// based on their authentication and profile state.
class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<sb.AuthState>(
      stream: sb.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = sb.Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        // CRITICAL: If this is a password recovery event, stay on the reset screen
        if (event == sb.AuthChangeEvent.passwordRecovery) {
          return const LinkSpecAuthScreen();
        }

        if (session == null) {
          return const LoginScreen();
        }

        return FutureBuilder<Map<String, dynamic>?>(
          future: SupabaseService.getCurrentUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066CC)),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;
            
            // If profile record doesn't exist yet or domain_id is null,
            // the user needs to complete domain selection.
            if (profile == null || profile['domain_id'] == null) {
              return const DomainSelectionScreen();
            }

            // Sync domain state immediately if it exists
            final profileDomain = profile['domain_id'] as String?;
            if (profileDomain != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ref.read(currentDomainProvider.notifier).state = profileDomain;
                }
              });
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
