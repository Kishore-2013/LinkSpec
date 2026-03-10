import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../services/linkspec_notify.dart';
import 'dart:async';
import '../widgets/aw_logo.dart';
import '../services/supabase_service.dart';

/// Login Screen — Unified Microsoft 365 Authentication.
/// Features a single, premium 'Sign in with Microsoft' entry point.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ─────────────────────────────────────────────────────────────────────────
  // Design tokens — Ultra-Minimalist
  static const _bg         = Color(0xFFF8F9FB); 
  static const _surface    = Color(0xFFFFFFFF);
  static const _textDark   = Color(0xFF1C1C1E);
  static const _textMid    = Color(0xFF8E8E93);
  static const _border     = Color(0xFFE5E5EA);

  // ── state ────────────────────────────────────────────────────────────────
  bool _isLoading = false;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // blob float animations
  late final AnimationController _blobCtrl;
  late final Animation<double> _blobFloat1; 
  late final Animation<double> _blobFloat2; 
  late final StreamSubscription<sb.AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    _blobCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _blobFloat1 = Tween<double>(begin: 0, end: -16).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut));
    _blobFloat2 = Tween<double>(begin: 0, end: 14).animate(CurvedAnimation(parent: _blobCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)));

    _authSubscription = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.signedIn || data.event == sb.AuthChangeEvent.tokenRefreshed) {
        // Redirection handled by AuthWrapper, but localized logic can go here.
      }
    });

    // INTERCEPT: If the URL contains recovery parameters, redirect to dedicated auth screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('code') || uri.fragment.contains('code=')) {
        Navigator.of(context).pushReplacementNamed('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _blobCtrl.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleMicrosoftLogin() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInWithMicrosoft();
    } catch (e) {
      if (mounted) LinkSpecNotify.show(context, LinkSpecNotify.mapError(e), LinkSpecNotifyType.warning);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/marble_texture.svg',
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.dstATop),
            ),
          ),
          
          // Decorative Blobs
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -20, left: -20,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(offset: Offset(0, _blobFloat1.value), child: child),
                    child: Opacity(opacity: 0.25, child: SvgPicture.asset('assets/svg/soft_coral.svg', width: 350, color: Colors.grey[300])),
                  ),
                ),
                Positioned(
                  bottom: -90, left: -130,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(offset: Offset(_blobFloat2.value * 0.4, _blobFloat2.value), child: child),
                    child: Opacity(opacity: 0.2, child: SvgPicture.asset('assets/svg/soft_green_blob.svg', width: 300, color: Colors.grey[300])),
                  ),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 900;
                return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: const Color(0xFFF0F4FF))),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 48, 48, 180),
                  child: SvgPicture.asset('assets/svg/undraw_login_weas.svg', fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(60.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const AWLogo(size: 80, showAppName: false),
                    const SizedBox(height: 24),
                    const Text(
                      'Unite with your\nprofessional domain.',
                      style: TextStyle(color: _textDark, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LinkSpec is the domain-gated networking platform\nfor the modern professional.',
                      style: TextStyle(color: _textDark.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(padding: const EdgeInsets.all(60), child: _buildFormContent()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _buildFormContent()),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AWLogo(size: 64, showAppName: true)),
        const SizedBox(height: 48),
        const Text(
          'Join the community',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in with your organization to access your domain feed.',
          style: TextStyle(fontSize: 15, color: _textMid),
        ),
        const SizedBox(height: 48),
        
        _MicrosoftButton(isLoading: _isLoading, onTap: _isLoading ? null : _handleMicrosoftLogin),
        
        const SizedBox(height: 32),
        const Divider(color: _border),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () {
              LinkSpecNotify.show(context, "LinkSpec uses Microsoft 365 for secure, domain-gated access. Please contact your administrator if you cannot sign in.", LinkSpecNotifyType.info);
            },
            child: const Text('Why Microsoft 365?', style: TextStyle(color: _textMid, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _MicrosoftButton extends StatelessWidget {
  const _MicrosoftButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.business_rounded, size: 22),
      label: Text(isLoading ? 'Signing in...' : 'Sign in with Microsoft 365'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
