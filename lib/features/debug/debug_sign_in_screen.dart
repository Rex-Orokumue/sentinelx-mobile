import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Dev-only (route exists only when DEBUG_TOOLS is true). Proves the Phase 0 exit criterion:
/// sign in with Supabase, call the bearer-authenticated GET /me, see the roles that will drive
/// the role-aware Admin section. Replaced by the real login flow in Phase 1.
class DebugSignInScreen extends ConsumerStatefulWidget {
  const DebugSignInScreen({super.key});

  @override
  ConsumerState<DebugSignInScreen> createState() => _DebugSignInScreenState();
}

class _DebugSignInScreenState extends ConsumerState<DebugSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _output = 'Not signed in.';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      final me = await ref.read(apiClientProvider).getMe();
      _output = 'OK ${me.id}\nroles: ${me.roles}\nisStaff: ${me.isStaff}  isAdmin: ${me.isAdmin}\n'
          'username: ${me.profile?.username}';
    } on ApiException catch (e) {
      _output = 'API error: $e';
    } catch (e) {
      _output = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug sign-in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('debug-sign-in'),
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Working…' : 'Sign in and call /me'),
          ),
          const SizedBox(height: 16),
          SelectableText(_output),
        ],
      ),
    );
  }
}
