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

/// Entry point wrapper that handles fast domain-based routing.
/// Prevents redundant delays and ensures users are routed correctly.
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
        // If the stream itself has an error (e.g., 422 during session refresh)
        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            LinkSpecNotify.show(context, LinkSpecNotify.mapError('session_timeout'), LinkSpecNotifyType.info);
          });
          return const LoginScreen();
        }

        final session = sb.Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        // GUARD: STRICT PASSWORD RECOVERY LOCK
        // If the session is in passwordRecovery mode, we MUST lock the user
        // on the reset screen and prohibit Home access.
        if (event == sb.AuthChangeEvent.passwordRecovery) {
          return const LinkSpecAuthScreen();
        }

        if (session == null) {
          return const LoginScreen();
        }

        // SECURITY CHECK: If session is present but it's a 'half-logged-in' state
        // from a bypassed recovery, force sign out.
        final uri = Uri.base;
        final hasRecoveryIntent = uri.queryParameters.containsKey('code') || 
                                 uri.fragment.contains('code=') ||
                                 uri.fragment.contains('type=recovery');
        
        // If moving to home but was previously in recovery without finishing
        if (event == sb.AuthChangeEvent.signedIn && hasRecoveryIntent) {
           WidgetsBinding.instance.addPostFrameCallback((_) async {
             LinkSpecNotify.show(context, "Ohh! no, we still need you to set your new password before you can enter. Could you please finish that first?", LinkSpecNotifyType.warning);
             // Safety: Clean out the bypass session
             await sb.Supabase.instance.client.auth.signOut();
           });
           return const LinkSpecAuthScreen();
        }

        // FETCH PROFILE: With Timeout and Error Catch to prevent infinite loading.
        return FutureBuilder<Map<String, dynamic>?>(
          future: SupabaseService.getCurrentUserProfile()
              .timeout(const Duration(seconds: 8)),
          builder: (context, profileSnapshot) {
            // Loading State
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

            // Error or Timeout State: Fallback to Login and show Soothing Popup
            if (profileSnapshot.hasError) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                LinkSpecNotify.show(context, LinkSpecNotify.mapError('session_timeout'), LinkSpecNotifyType.info);
              });
              return const LoginScreen();
            }

            final profile = profileSnapshot.data;
            
            // If profile record doesn't exist yet or domain_id is null,
            // the user needs to complete domain selection.
            if (profile == null || profile['domain_id'] == null) {
              return const DomainSelectionScreen();
            }

            // Sync domain state immediately
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
