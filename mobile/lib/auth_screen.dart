/// Sign-in / sign-up screen shown by the auth gate in Firebase
/// mode when nobody is signed in.
///
/// Email + password only (Firebase Auth). Errors are translated
/// via [friendlyAuthError] — raw Firebase codes are not
/// parent-friendly at 3 AM.
library;

import 'package:flutter/material.dart';

import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await widget.auth.signUp(_email.text, _password.text);
      } else {
        await widget.auth.signIn(_email.text, _password.text);
      }
      // On success the auth gate swaps this screen for the app.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.favorite,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('FairCare',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  _signUp
                      ? 'Create your account to start sharing care logs with your partner.'
                      : 'Welcome back — sign in to see your shared care log.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy
                      ? 'Please wait…'
                      : _signUp
                          ? 'Create account'
                          : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                  child: Text(_signUp
                      ? 'Already have an account? Sign in'
                      : 'New to FairCare? Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
