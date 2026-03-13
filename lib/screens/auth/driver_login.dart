import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../driver_screen.dart';
import '../../services/security_service.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  static const String _attemptKey = 'driver_login';

  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
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

  Future loginDriver() async {
    final remaining = SecurityService.getRemainingLock(_attemptKey);
    if (remaining != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many attempts. Try again in ${_formatRemaining(remaining)}.',
          ),
        ),
      );
      return;
    }

    final normalizedEmail = SecurityService.normalizeEmail(email.text);
    final normalizedPassword = SecurityService.normalizePassword(password.text);

    if (!SecurityService.isValidEmail(normalizedEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: normalizedEmail, password: normalizedPassword);

      SecurityService.registerSuccess(_attemptKey);

      if (!mounted) return;

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const DriverScreen()));
    } on FirebaseAuthException {
      SecurityService.registerFailure(_attemptKey);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Driver Login Failed. Check credentials.")));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Something went wrong. Try again.")));
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Login")),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 50),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.drive_eta, size: 80),
                      const SizedBox(height: 20),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration:
                            const InputDecoration(labelText: "Driver Email"),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: password,
                        obscureText: true,
                        keyboardType: TextInputType.visiblePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration:
                            const InputDecoration(labelText: "Password"),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : loginDriver,
                          child: loading
                              ? const CircularProgressIndicator()
                              : const Text("Login"),
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
    );
  }
}
