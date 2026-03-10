import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../widgets/aw_logo.dart';
import '../services/linkspec_notify.dart';

enum ResetState { initial, loading, success }

/// Dedicated Reset Password Page for LinkSpec.
class LinkSpecAuthScreen extends StatefulWidget {
  const LinkSpecAuthScreen({Key? key}) : super(key: key);

  @override
  State<LinkSpecAuthScreen> createState() => _LinkSpecAuthScreenState();
}

class _LinkSpecAuthScreenState extends State<LinkSpecAuthScreen> {
  ResetState _s = ResetState.initial;
  final _p = TextEditingController(), _c = TextEditingController();
  final _key = GlobalKey<FormState>();
  
  bool _obsP = true;
  bool _obsC = true;
  
  StreamSubscription<sb.AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sub = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _s = ResetState.initial);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _p.dispose(); 
    _c.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) {
      LinkSpecNotify.show(context, LinkSpecNotify.mapError('empty'), LinkSpecNotifyType.warning);
      return;
    }
    
    // Check if passwords match
    if (_p.text.trim() != _c.text.trim()) {
      LinkSpecNotify.show(context, LinkSpecNotify.mapError('mismatch'), LinkSpecNotifyType.warning);
      return;
    }

    setState(() => _s = ResetState.loading);
    try {
      await sb.Supabase.instance.client.auth.updateUser(sb.UserAttributes(password: _p.text.trim()));
      
      setState(() => _s = ResetState.success);
      
      // Sequential Flow: Show 'Perfect!' popup with Okay button
      if (mounted) {
        LinkSpecNotify.showDialog(
          context, 
          'Perfect! Your password is updated. Could you please log in now to see your professional network?', 
          LinkSpecNotifyType.success,
          onConfirm: () async {
            // Sign out to force manual login as per sequential flow requirements
            await sb.Supabase.instance.client.auth.signOut();
            if (mounted) context.go('/auth');
          },
        );
      }
      
    } catch (e) {
      LinkSpecNotify.show(context, LinkSpecNotify.mapError(e), LinkSpecNotifyType.warning);
      setState(() => _s = ResetState.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(
        child: _s == ResetState.loading 
            ? const CircularProgressIndicator() 
            : _body(),
      ),
    );
  }

  Widget _body() => SingleChildScrollView(
    padding: const EdgeInsets.all(24), 
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(children: [
        const AWLogo(size: 60, showAppName: true), 
        const SizedBox(height: 48),
        
        if (_s != ResetState.success) ...[
          _view('Update Identity'),
          const Text(
            'Enter your new secure details.', 
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Form(
            key: _key, 
            child: Column(children: [
              _field(
                _p, 
                'New Password', 
                Icons.key_outlined, 
                obs: _obsP, 
                toggle: () => setState(() => _obsP = !_obsP),
              ), 
              const SizedBox(height: 16),
              _field(
                _c, 
                'Confirm Password', 
                Icons.verified_user_outlined, 
                obs: _obsC, 
                toggle: () => setState(() => _obsC = !_obsC),
              ),
            ]),
          ),
          _btn('Save and Login', _reset),
        ] else ...[
          const Icon(Icons.check_circle, size: 80, color: Color(0xFF166534)),
          const SizedBox(height: 24),
          _view('Verified'),
          const Text(
            'Identity updated. Redirecting to your workspace...', 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ]),
    ),
  );

  Widget _view(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12), 
    child: Text(
      t, 
      style: const TextStyle(
        fontSize: 28, 
        fontWeight: FontWeight.w900, 
        letterSpacing: -0.8,
      ),
    ),
  );

  Widget _btn(String t, VoidCallback o) => Padding(
    padding: const EdgeInsets.only(top: 32), 
    child: SizedBox(
      width: double.infinity, 
      height: 56,
      child: ElevatedButton(
        onPressed: o, 
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: Colors.white, 
          elevation: 0, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ), 
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ),
  );

  Widget _field(
    TextEditingController c, 
    String h, 
    IconData i, 
    {required bool obs, VoidCallback? toggle, String? Function(String?)? v}
  ) => TextFormField(
    controller: c, 
    obscureText: obs, 
    validator: v, 
    decoration: InputDecoration(
      hintText: h, 
      prefixIcon: Icon(i, color: Colors.grey.shade400, size: 22),
      suffixIcon: toggle != null 
          ? IconButton(
              icon: Icon(
                obs ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
                color: Colors.grey.shade400, 
                size: 20,
              ),
              onPressed: toggle,
            ) 
          : null,
      filled: true, 
      fillColor: Colors.white, 
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Colors.grey.shade200),
      ), 
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16), 
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
  );
}
