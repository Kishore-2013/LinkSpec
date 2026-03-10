import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/aw_logo.dart';

enum AuthState { initial, loading, mailSent, resetting, success }

/// Final Unified LinkSpecAuthScreen: Gmail OTP vs MS360 Professional Login.
/// Managed via state enums. Single file, under 200 lines.
class LinkSpecAuthScreen extends StatefulWidget {
  const LinkSpecAuthScreen({Key? key}) : super(key: key);
  @override
  State<LinkSpecAuthScreen> createState() => _LinkSpecAuthScreenState();
}

class _LinkSpecAuthScreenState extends State<LinkSpecAuthScreen> {
  AuthState _s = AuthState.initial;
  final _email = TextEditingController(), _p = TextEditingController(), _c = TextEditingController();
  final _key = GlobalKey<FormState>();

  @override
  void initState() { super.initState(); _check(); }

  void _check() {
    final u = Uri.base;
    if (u.query.contains('code=') || u.fragment.contains('code=') || u.fragment.contains('type=recovery')) {
      setState(() => _s = AuthState.resetting);
    }
  }

  Future<void> _entry() async {
    final m = _email.text.trim().toLowerCase();
    if (!m.contains('@')) return _msg('Invalid email', e: true);
    setState(() => _s = AuthState.loading);
    try {
      if (m.endsWith('@gmail.com')) {
        // Trigger Gmail OTP/Reset flow
        await SupabaseService.sendPasswordResetEmail(m);
        setState(() => _s = AuthState.mailSent);
      } else {
        // Corporate Domain -> MS360 OAuth Login
        await SupabaseService.signInWithMicrosoft();
        setState(() => _s = AuthState.initial);
      }
    } catch (e) { _msg(e.toString(), e: true); setState(() => _s = AuthState.initial); }
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _s = AuthState.loading);
    try {
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
      if (_s == AuthState.initial) ...[_view('Authentication'), _field(_email, 'Corporate or Gmail Email', Icons.person), _btn('Identify Domain', _entry)],
      if (_s == AuthState.mailSent) ...[_view('Check Inbox'), const Text('A secure link was sent. Check your mail.', textAlign: TextAlign.center), _btn('Back', () => setState(() => _s = AuthState.initial), o_: true)],
      if (_s == AuthState.resetting) ...[_view('Reset Identity'), Form(key: _key, child: Column(children: [
        _field(_p, 'New Secret', Icons.key, obs: true), const SizedBox(height: 12),
        _field(_c, 'Confirm Secret', Icons.verified, obs: true, v: (x) => x != _p.text ? 'Mismatch' : null),
      ])), _btn('Update Account', _reset)],
      if (_s == AuthState.success) ...[const Icon(Icons.check_circle, size: 80, color: Colors.green), _view('Verified'), const Text('Login successful. Redirecting...')],
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
