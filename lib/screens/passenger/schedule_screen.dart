import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Bus Schedule"),
      ),

      body: ListView(

        padding: const EdgeInsets.all(20),

        children: const [

          ListTile(
            leading: Icon(Icons.directions_bus),
            title: Text("Bus 101"),
            subtitle: Text("8:00 AM - 5:00 PM"),
          ),

          ListTile(
            leading: Icon(Icons.directions_bus),
            title: Text("Bus 202"),
            subtitle: Text("9:00 AM - 6:00 PM"),
          ),

          ListTile(
            leading: Icon(Icons.directions_bus),
            title: Text("Bus 303"),
            subtitle: Text("10:00 AM - 7:00 PM"),
          ),

        ],
      ),

    );

  }
}