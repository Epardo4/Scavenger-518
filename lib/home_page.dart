import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget{
  const HomePage({super.key});

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
    Widget build(BuildContext context){
      final user = FirebaseAuth.instance.currentUser;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Scavenger App'),
          actions: [
            IconButton(
              onPressed: logOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Log Out'
            )
          ]
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold
                )
              ),

              const SizedBox(height: 20),

              Text(
                'You are logged in as: ',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey[700]
                )
              ),

              const SizedBox(height: 8),

              Text(
                user?.email ?? 'Unknown User',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold
                )
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: logOut,
                child: const Text('Log Out')
              )
            ]
          )
        )
      );
    }
  }