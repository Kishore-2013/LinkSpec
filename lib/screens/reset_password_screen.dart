import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dart:async';
import '../widgets/aw_logo.dart';

enum AuthState { initial, loading, success }

/// Unified Reset Screen for LinkSpec: Only handles New Password entry.
class LinkSpecAuthScreen extends StatefulWidget {
  const LinkSpecAuthScreen({Key? key}) : super(key: key);

  @override
  State<LinkSpecAuthScreen> createState() => _LinkSpecAuthScreenState();
}

class _LinkSpecAuthScreenState extends State<LinkSpecAuthScreen> {
  AuthState _s = AuthState.initial;
  final _p = TextEditingController(), _c = TextEditingController();
  final _key = GlobalKey<FormState>();
  
  bool _obsP = true;
  bool _obsC = true;
  
  // Use sb alias to resolve type mismatch with local AuthState enum
  StreamSubscription<sb.AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _s = AuthState.initial);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _p.dispose(); _c.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _s = AuthState.loading);
    try {
      await sb.Supabase.instance.client.auth.updateUser(sb.UserAttributes(password: _p.text.trim()));
      setState(() => _s = AuthState.success);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      });
    } catch (e) {
      _msg(e.toString(), e: true);
      setState(() => _s = AuthState.initial);
    }
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
      
      if (_s == AuthState.initial) ...[
        _view('Update Identity'),
        const Text('Enter your new secure details.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 32),
        Form(key: _key, child: Column(children: [
          _field(_p, 'New Password', Icons.key, obs: _obsP, 
            toggle: () => setState(() => _obsP = !_obsP)), 
          const SizedBox(height: 12),
          _field(_c, 'Confirm Password', Icons.verified, obs: _obsC, 
            v: (x) => x != _p.text ? 'Mismatch' : null,
            toggle: () => setState(() => _obsC = !_obsC)),
        ])),
        _btn('Save and Login', _reset)
      ],

      if (_s == AuthState.success) ...[
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        _view('Verified'),
        const Text('Identity updated. Redirecting to your workspace...', textAlign: TextAlign.center),
      ],
    ]),
  ));

  Widget _view(String t) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8)));

  Widget _btn(String t, VoidCallback o) => Padding(padding: const EdgeInsets.only(top: 24), child: SizedBox(width: double.infinity, height: 54,
    child: ElevatedButton(onPressed: o, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1C1E),
      foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), 
      child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))));

  Widget _field(TextEditingController c, String h, IconData i, {required bool obs, VoidCallback? toggle, String? Function(String?)? v}) => 
    TextFormField(controller: c, obscureText: obs, validator: v, decoration: InputDecoration(hintText: h, prefixIcon: Icon(i, color: Colors.grey),
      suffixIcon: toggle != null ? GestureDetector(onTap: toggle, child: Icon(obs ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20)) : null,
      filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))), contentPadding: const EdgeInsets.all(18)));
}
