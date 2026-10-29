
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int currentPage = 1;
  int currentList = 0;

  Future<Map<String, dynamic>?> getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    // Make sure a user is logged in.
    if (user == null) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        return userDoc.data();
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('Error getting user data: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scavenger'),
      ),

      body: Center(
        child: SizedBox(
          width: 400,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FutureBuilder<Map<String, dynamic>?>(
              future: getUserData(),
              builder: (context, snapshot) {
                // While loading data.
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // If an error occurs.
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading profile data.'),
                  );
                }

                // If no user document exists.
                final userData = snapshot.data;

                if (userData == null) {
                  return const Center(
                    child: Text('No profile data found.'),
                  );
                }

                return Column(
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 40),

                    const Icon(
                      Icons.person,
                      size: 48,
                    ),

                    const SizedBox(height: 40),

                    Text(
                      '${userData['username']}',
                      style: const TextStyle(fontSize: 18),
                    ),

                    SizedBox(height: 200,
                      child: mediaListBuild(context)
                    )
                  ],
                );
              },
            ),
          ),
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentPage,
        onTap: (value) {
          setState(() {
            currentPage = value;
          });

          if (currentPage == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget mediaListBuild(BuildContext context){
    return DefaultTabController(
      length: 2,
      child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
            ),
                    TabBar(
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      tabs: [
                        Tab(text: 'To-Watch List'),
                        Tab(text: 'Watched List')
                      ],
                    ),
                    Expanded(
                       child: TabBarView(
                          children: [
                            Center(child: Text('View for To-Watch List')),
                            Center(child: Text('View for Watched List'))
                          ]
                        )
                      )
          ]
        )

    );
  }
}
