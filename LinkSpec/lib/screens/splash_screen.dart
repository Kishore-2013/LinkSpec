import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Splash Screen - Determines initial route based on auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

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
    _redirect();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Not logged in - go to login
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Check if user has completed domain selection
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', session.user.id)
            .maybeSingle();

        if (!mounted) return;

        if (profile == null) {
          // Profile doesn't exist - needs domain selection
          Navigator.of(context).pushReplacementNamed('/domain-selection');
        } else {
          // Profile exists - go to home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        // Error checking profile - go to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
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
              // Logo with shadow
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.business_center,
                  size: 80,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),
              
              // App Name
              Text(
                'LinkSpec',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              
              // Tagline
              Text(
                'Professional Networking, Domain-Focused',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
