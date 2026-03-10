import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'dart:async';
import '../widgets/aw_logo.dart';
import '../services/notification_service.dart';

enum AuthState { initial, loading, success }

/// Dedicated Reset Password Page for LinkSpec.
/// Handles the access_token from the URL fragment automatically via Supabase.
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
    // Cleanup to prevent memory leaks and duplicate triggers
    _sub?.cancel();
    _p.dispose(); 
    _c.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_key.currentState!.validate()) return;
    
    // Check if passwords match
    if (_p.text.trim() != _c.text.trim()) {
      NotificationService.showWarning("The passwords don't seem to match. Could you please double-check them for us?");
      return;
    }

    setState(() => _s = AuthState.loading);
    try {
      // Technical requirement: Use supabase.auth.updateUser for the password change
      await sb.Supabase.instance.client.auth.updateUser(sb.UserAttributes(password: _p.text.trim()));
      
      setState(() => _s = AuthState.success);
      
      // Soothing Success Popup
      NotificationService.showSuccess(
        'Your password has been successfully updated. Could you please log in now using your new secure details? We’re ready for you!',
        onDone: () {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
      );
      
    } catch (e) {
      // Error Handling: Automatic soothing transformation occurs in NotificationService
      NotificationService.showWarning(e);
      setState(() => _s = AuthState.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(
        child: _s == AuthState.loading 
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
        
        if (_s != AuthState.success) ...[
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
                v: (x) => (x == null || x.isEmpty) ? 'Required' : null,
              ),
            ]),
          ),
          _btn('Save and Login', _reset),
        ] else ...[
          // Success View - Shown while the popup is visible
          const Icon(Icons.check_circle, size: 80, color: Color(0xFF2E7D32)),
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
    validator: v ?? (x) => (x == null || x.isEmpty) ? 'Required' : null, 
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
