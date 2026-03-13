import 'package:flutter/material.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Trip History"),
      ),

      body: ListView(

        children: const [

          ListTile(
            leading: Icon(Icons.route),
            title: Text("Trip 1"),
            subtitle: Text("City Center → Bus Stand"),
          ),

          ListTile(
            leading: Icon(Icons.route),
            title: Text("Trip 2"),
            subtitle: Text("University → Market"),
          ),

        ],
      ),

    );
  }
}