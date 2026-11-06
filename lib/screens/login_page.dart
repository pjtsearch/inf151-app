import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static Future<void>? _googleInitialization;
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_creatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        final name = _name.text.trim();
        if (name.isNotEmpty) await credential.user?.updateDisplayName(name);
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyAuthError(error));
    } catch (_) {
      _showError('Could not sign in right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
      } else {
        final google = GoogleSignIn.instance;
        _googleInitialization ??= google.initialize();
        await _googleInitialization;
        final account = await google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(
            code: 'missing-google-token',
            message: 'Google did not return an ID token.',
          );
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyAuthError(error));
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google sign-in could not be completed. Check Firebase and Google setup.');
      }
    } catch (_) {
      _showError('Google sign-in could not be completed. Check Firebase and Google setup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      _showError(_friendlyAuthError(error));
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _toggleMode() => setState(() {
    _creatingAccount = !_creatingAccount;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                Text(
                  _creatingAccount ? 'Create account' : 'Sign in',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _creatingAccount ? 'Create your parent account' : 'Parent account',
                  style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_creatingAccount) ...[
                        _label('Name'),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: _decoration('Your name'),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _label('Email'),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: _decoration('you@example.com'),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) return 'Enter a valid email address.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _label('Password'),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        textInputAction: _creatingAccount ? TextInputAction.next : TextInputAction.done,
                        autofillHints: [_creatingAccount ? AutofillHints.newPassword : AutofillHints.password],
                        decoration: _decoration('Password').copyWith(
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.isEmpty) return 'Enter your password.';
                          if (_creatingAccount && password.length < 6) return 'Use at least 6 characters.';
                          return null;
                        },
                      ),
                      if (_creatingAccount) ...[
                        const SizedBox(height: 16),
                        _label('Confirm password'),
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          decoration: _decoration('Confirm password'),
                          validator: (value) => value != _password.text ? 'Passwords do not match.' : null,
                        ),
                      ] else ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _busy ? null : _resetPassword, child: const Text('Forgot password?')),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _busy ? null : _submitEmail,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_creatingAccount ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _busy ? null : _toggleMode,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          child: Text(_creatingAccount ? 'I already have an account' : 'Create a parent account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: const OutlineInputBorder(),
  );
}

String _friendlyAuthError(FirebaseAuthException error) => switch (error.code) {
  'email-already-in-use' => 'An account already exists for that email.',
  'invalid-email' => 'Enter a valid email address.',
  'weak-password' => 'Choose a stronger password.',
  'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
  'too-many-requests' => 'Too many attempts. Please try again later.',
  'network-request-failed' => 'Check your internet connection and try again.',
  _ => error.message ?? 'Authentication failed. Please try again.',
};
