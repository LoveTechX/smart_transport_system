import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/security_service.dart';
import '../passenger_screen.dart';

class PassengerLoginScreen extends StatefulWidget {
  const PassengerLoginScreen({super.key});

  @override
  State<PassengerLoginScreen> createState() => _PassengerLoginScreenState();
}

class _PassengerLoginScreenState extends State<PassengerLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  static const String _attemptKey = 'passenger_login';

  bool loading = false;
  bool isSignupMode = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String _formatRemaining(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Future<void> _submit() async {
    final normalizedEmail = SecurityService.normalizeEmail(email.text);
    final normalizedPassword = SecurityService.normalizePassword(password.text);

    if (!SecurityService.isValidEmail(normalizedEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    if (!SecurityService.isValidPassword(normalizedPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SecurityService.passwordPolicyMessage())),
      );
      return;
    }

    if (isSignupMode && normalizedPassword != confirmPassword.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confirm password does not match.')),
      );
      return;
    }

    if (!isSignupMode) {
      final remaining = SecurityService.getRemainingLock(_attemptKey);
      if (remaining != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many attempts. Try again in ${_formatRemaining(remaining)}.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => loading = true);

    try {
      if (isSignupMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
        SecurityService.registerSuccess(_attemptKey);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PassengerScreen()),
      );
    } on FirebaseAuthException catch (error) {
      if (!isSignupMode) {
        SecurityService.registerFailure(_attemptKey);
      }

      String message = 'Authentication failed. Please try again.';
      if (error.code == 'email-already-in-use') {
        message = 'Account already exists. Please login instead.';
      } else if (error.code == 'weak-password') {
        message = SecurityService.passwordPolicyMessage();
      } else if (error.code == 'user-not-found' ||
          error.code == 'wrong-password') {
        message = 'Invalid credentials.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          title: Text(isSignupMode ? 'Passenger Sign Up' : 'Passenger Login')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person,
                              size: 72, color: colorScheme.primary),
                          const SizedBox(height: 16),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.username],
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: password,
                            obscureText: true,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.password],
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                          ),
                          if (isSignupMode) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: confirmPassword,
                              obscureText: true,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                  labelText: 'Confirm Password'),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              SecurityService.passwordPolicyMessage(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : _submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(isSignupMode
                                      ? 'Create Account'
                                      : 'Login'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () => setState(
                                    () => isSignupMode = !isSignupMode),
                            child: Text(
                              isSignupMode
                                  ? 'Already have an account? Login'
                                  : 'No account? Create one',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
