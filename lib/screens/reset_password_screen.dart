import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/supabase_service.dart';
import '../widgets/aw_logo.dart';

enum AuthState { initial, loading, mailSent, resetting, success }

/// Unified Auth Screen for LinkSpec: Prevents auto-login and maintains Same-Page Reset.
class LinkSpecAuthScreen extends StatefulWidget {
  const LinkSpecAuthScreen({Key? key}) : super(key: key);
  @override
  State<LinkSpecAuthScreen> createState() => _LinkSpecAuthScreenState();
}

class _LinkSpecAuthScreenState extends State<LinkSpecAuthScreen> {
  AuthState _s = AuthState.initial;
  final _email = TextEditingController(), _p = TextEditingController(), _c = TextEditingController();
  final _key = GlobalKey<FormState>();
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() { 
    super.initState(); 
    _listen();
  }

  void _listen() {
    // Listen for incoming password recovery events from deep links
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _s = AuthState.resetting);
      }
    });

    // Check existing URL parameters as a fallback (Web)
    final u = Uri.base;
    if (u.toString().contains('type=recovery') || u.fragment.contains('type=recovery')) {
      setState(() => _s = AuthState.resetting);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _email.dispose(); _p.dispose(); _c.dispose();
    super.dispose();
  }

  Future<void> _entry() async {
    final m = _email.text.trim().toLowerCase();
    if (!m.contains('@')) return _msg('Invalid email', e: true);
    setState(() => _s = AuthState.loading);
    try {
      if (m.endsWith('@gmail.com')) {
        await SupabaseService.sendPasswordResetEmail(m);
        setState(() => _s = AuthState.mailSent);
      } else {
        await SupabaseService.signInWithMicrosoft();
        setState(() => _s = AuthState.initial);
      }
    } catch (e) { 
      if (e.toString().contains('429')) {
        _msg('Rate limited. Showing reset view...', e: true);
        setState(() => _s = AuthState.resetting);
      } else {
        _msg(e.toString(), e: true); setState(() => _s = AuthState.initial); 
      }
    }
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _s = AuthState.loading);
    try {
      // Direct update in session created by recovery token. No redirect until success.
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _p.text.trim()));
      setState(() => _s = AuthState.success);
      Future.delayed(const Duration(seconds: 2), () => Navigator.pushReplacementNamed(context, '/home'));
    } catch (e) { _msg(e.toString(), e: true); setState(() => _s = AuthState.resetting); }
  }

  void _msg(String m, {bool e = false}) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: e ? Colors.red : Colors.green, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(child: _s == AuthState.loading ? const CircularProgressIndicator() : _body()),
    );
  }

  Widget _body() => SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 400),
    child: Column(children: [
      const AWLogo(size: 60, showAppName: true), const SizedBox(height: 48),
      // 1. Initial State: Identify Domain (Gmail vs MS360)
      if (_s == AuthState.initial) ...[
        _view('Authentication'), 
        _field(_email, 'Corporate or Gmail Email', Icons.person), 
        _btn('Identify Domain', _entry)
      ],
      // 2. Mail Sent State: Confirmation
      if (_s == AuthState.mailSent) ...[
        _view('Check Inbox'), 
        const Text('A secure link was sent. Check your mail.', textAlign: TextAlign.center), 
        _btn('Back', () => setState(() => _s = AuthState.initial), o_: true)
      ],
      // 3. Resetting State: Only New Password Fields (Bypasses Domain Check)
      if (_s == AuthState.resetting) ...[
        _view('Update Identity'), 
        const Text('Enter your new secure details.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        Form(key: _key, child: Column(children: [
          _field(_p, 'New Secret', Icons.key, obs: true), const SizedBox(height: 12),
          _field(_c, 'Confirm Secret', Icons.verified, obs: true, v: (x) => x != _p.text ? 'Mismatch' : null),
        ])), 
        _btn('Save and Login', _reset)
      ],
      // 4. Success State: Celebration
      if (_s == AuthState.success) ...[
        const Icon(Icons.check_circle, size: 80, color: Colors.green), 
        _view('Verified'), 
        const Text('Identity updated. Redirecting to your workspace...')
      ],
    ]),
  ));

  Widget _view(String t) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8)));

  Widget _btn(String t, VoidCallback o, {bool o_ = false}) => Padding(padding: const EdgeInsets.only(top: 24), child: SizedBox(width: double.infinity, height: 54, 
    child: ElevatedButton(onPressed: o, style: ElevatedButton.styleFrom(backgroundColor: o_ ? Colors.white : const Color(0xFF1C1C1E), 
      foregroundColor: o_ ? Colors.black : Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
      side: o_ ? const BorderSide(color: Color(0xFFE5E5EA), width: 1.5) : null), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))));

  Widget _field(TextEditingController c, String h, IconData i, {bool obs = false, String? Function(String?)? v}) => 
    TextFormField(controller: c, obscureText: obs, validator: v, decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.grey), 
      filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))), contentPadding: const EdgeInsets.all(18)));
}
