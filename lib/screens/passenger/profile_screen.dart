import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("My Profile"),
      ),

      body: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          children: const [

            CircleAvatar(
              radius: 50,
              child: Icon(Icons.person, size: 50),
            ),

            SizedBox(height: 20),

            Text(
              "Passenger Name",
              style: TextStyle(
                fontSize: 22,
                
              ),
            ),

            SizedBox(height: 10),

            Text(
              "passenger@email.com",
              style: TextStyle(fontSize: 16),
            ),

          ],
        ),
      ),

    );

  }
}