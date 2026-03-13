import 'package:flutter/material.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Tickets")),
      body: const Center(
        child: Text("My Tickets"),
      ),
    );
  }
}