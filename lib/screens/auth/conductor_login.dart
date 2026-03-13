import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../conductor_screen.dart';
import '../../services/security_service.dart';

class ConductorLoginScreen extends StatefulWidget {
  const ConductorLoginScreen({super.key});

  @override
  State<ConductorLoginScreen> createState() => _ConductorLoginScreenState();
}

class _ConductorLoginScreenState extends State<ConductorLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  static const String _attemptKey = 'conductor_login';

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

  Future login() async {
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

    if (!SecurityService.isValidPassword(normalizedPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SecurityService.passwordPolicyMessage())),
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
          context, MaterialPageRoute(builder: (_) => const ConductorScreen()));
    } on FirebaseAuthException {
      SecurityService.registerFailure(_attemptKey);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Failed. Check credentials.")));
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
      appBar: AppBar(title: const Text("Conductor Login")),
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
                      const Icon(Icons.confirmation_number, size: 80),
                      const SizedBox(height: 20),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(labelText: "Email"),
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
                          onPressed: loading ? null : login,
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
