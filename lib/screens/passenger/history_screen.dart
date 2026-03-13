import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Travel History"),
      ),
      body: const Center(
        child: Text(
          "Travel History Screen",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}