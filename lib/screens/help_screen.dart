import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController controller = TextEditingController();

  String reply = "";

  bool showAgent = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// AI Help
  void solveProblem() {
    final String text = controller.text.trim().toLowerCase();

    showAgent = false;

    if (text.isEmpty) {
      setState(() {
        reply = "Please type your issue first.";
      });
      return;
    }

    if (text.contains("map")) {
      reply = "Check GPS and Internet.";
    } else if (text.contains("login")) {
      reply = "Restart app and login again.";
    } else if (text.contains("tracking")) {
      reply = "Driver tracking must be ON.";
    } else {
      reply = "AI could not solve problem.\nContact Agent.";

      showAgent = true;
    }

    setState(() {});
  }

  /// Agent Call
  void callAgent() async {
    final Uri phone = Uri.parse("tel:9876543210"); // apna number

    if (await canLaunchUrl(phone)) {
      await launchUrl(phone);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open dialer.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Help Center"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Describe your issue",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 300,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: "Type problem...",
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: solveProblem,
              child: const Text("Analyze with AI"),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  reply.isEmpty ? "AI response will appear here." : reply,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (showAgent)
              ElevatedButton.icon(
                onPressed: callAgent,
                icon: const Icon(Icons.support_agent),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                label: const Text("Call Support Agent"),
              ),
          ],
        ),
      ),
    );
  }
}
