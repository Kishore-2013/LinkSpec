import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../widgets/aw_logo.dart';

/// Splash Screen - Determines initial route based on auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  StreamSubscription<AuthState>? _authSub;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _controller.forward();

    // INTERCEPT: If the URL indicates a recovery attempt, jump to reset page immediately 
    // and stop the normal login redirect.
    final uri = Uri.base;
    final isRecovery = uri.queryParameters.containsKey('code') || 
                       uri.fragment.contains('code=') ||
                       uri.fragment.contains('type=recovery');

    if (isRecovery) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/reset-password');
      });
      return;
    }

    _redirect();
  }

  @override
  void dispose() {
    _controller.dispose();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _redirect() async {
    // Short delay for the logo animation to be visible
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted || _hasRedirected) return;
    _hasRedirected = true;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Not logged in → go to login immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    // User is authenticated — check if they completed domain selection.
    // Use a TIMEOUT so we never hang forever on slow networks.
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8)); // ← never hang forever

      if (!mounted) return;

      if (profile == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pushReplacementNamed('/domain-selection');
        });
      } else {
        // Respect deep links: don't force them back to /home if a specific path was provided.
        final initialPath = Uri.base.path;
        final targetRoute = (initialPath != '/' && initialPath.isNotEmpty && initialPath != '/login') 
            ? initialPath 
            : '/home';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pushReplacementNamed(targetRoute);
        });
      }
    } catch (e) {
      // Timeout, network error, or any Supabase error → send to login.
      debugPrint('SplashScreen redirect error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + App Name + Tagline
              const AWLogo(
                size: 100,
                showAppName: true,
                showTagline: true,
              ),
              const SizedBox(height: 48),
              
              // Loading Indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
