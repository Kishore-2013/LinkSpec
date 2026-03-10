import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:html' as html; // Used to clear the address bar
import '../widgets/aw_logo.dart';
import '../services/linkspec_notify.dart';
import '../services/supabase_service.dart';

/// LinkSpecAuthScreen: Unified Microsoft 365 Authentication Screen.
/// Replaces legacy internal password reset forms.
class LinkSpecAuthScreen extends StatefulWidget {
  const LinkSpecAuthScreen({Key? key}) : super(key: key);

  @override
  State<LinkSpecAuthScreen> createState() => _LinkSpecAuthScreenState();
}

class _LinkSpecAuthScreenState extends State<LinkSpecAuthScreen> {
  bool _isLoading = false;
  late final StreamSubscription<sb.AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    
    // 1. Clear URL parameters from address bar immediately to prevent re-validation on refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (html.window.location.href.contains('code=') || html.window.location.href.contains('type=recovery')) {
        // Clear the query & fragment without reloading the page
        html.window.history.replaceState({}, '', html.window.location.pathname);
      }
    });

    // 2. Resolve StreamSubscription<AuthState> type conflict
    _authSubscription = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.signedIn) {
        // SECURITY CHECK: If session is present but it's from a recovery flow, 
        // DO NOT allow navigation to home yet.
        final uri = Uri.base;
        final hasRecoveryIntent = uri.queryParameters.containsKey('code') || 
                                 uri.fragment.contains('code=') ||
                                 uri.fragment.contains('type=recovery');

        if (hasRecoveryIntent) {
          if (mounted) {
            LinkSpecNotify.show(context, "Ohh! no, we still need you to set your new password before you can enter. Could you please finish that first?", LinkSpecNotifyType.warning);
          }
          return; // Lock movement
        }

        if (mounted) context.go('/home');
      }
    });

    // 3. FORCE LOGOUT ON BYPASS: If a user refreshes and is in a half-logged-in state,
    // they should be kicked back to verification or logged out securely.
    _validateRecoverySession();
  }

  Future<void> _validateRecoverySession() async {
    final session = sb.Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // If we land here but already have a session, we should check if they can actually go home
      // or if they are stuck in a recovery loop.
      // If it's a regular session that bypassed the reset, force sign out.
      await sb.Supabase.instance.client.auth.signOut();
      if (mounted) {
         LinkSpecNotify.show(context, "Session expired or reset required. Please sign in again.", LinkSpecNotifyType.info);
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleMicrosoftLogin() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInWithMicrosoft();
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(context, "Microsoft authentication hiccup! Could you please try again?", LinkSpecNotifyType.warning);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AWLogo(size: 80, showAppName: true),
              const SizedBox(height: 48),
              
              const Text(
                'Identity Verification',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sign in with your professional domain account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleMicrosoftLogin,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.business_rounded, size: 24),
                    label: Text(
                      _isLoading ? 'Processing...' : 'Sign in with Microsoft 365',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // Microsoft official recovery redirection instruction
              TextButton(
                onPressed: () {
                  // Microsoft password recovery is handled via their official portal.
                  // We provide a supportive message or link to their portal.
                  LinkSpecNotify.show(
                    context, 
                    "Password recovery is handled securely via Microsoft. Please contact your domain administrator or use the Microsoft account portal.", 
                    LinkSpecNotifyType.info
                  );
                },
                child: const Text(
                  'Trouble signing in?',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
