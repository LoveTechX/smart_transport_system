import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {

  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text("Login"),
      ),

      body: Padding(

        padding: EdgeInsets.all(20),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(
              Icons.login,
              size: 80,
            ),

            SizedBox(height: 20),

            TextField(

              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),

            ),

            SizedBox(height: 15),

            TextField(

              obscureText: true,

              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),

            ),

            SizedBox(height: 20),

            ElevatedButton(

              onPressed: () {},

              child: Text("Login"),

            ),

          ],

        ),

      ),

    );

  }
}