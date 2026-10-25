import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tmdb_service.dart';
import 'Models/media.dart';
import 'media_details_page.dart';
import 'search_screen.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget{
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>{
  int currentPage = 1;
  @override
  Widget build(BuildContext context){
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scavenger')
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentPage,
        onTap: (value) {
          setState(() {currentPage = value;});
          if(currentPage == 0){
            Navigator.push(
              context,MaterialPageRoute(builder: (context) => const HomePage())
          );}
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person),label: "Profile")
        ]
        ),
    );
  }
}