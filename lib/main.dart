import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'auth_page.dart';
import 'main_layout.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Helper method to sync theme mode to user's Firestore document
  static Future<void> updateUserTheme(ThemeMode newMode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final themeStr = newMode == ThemeMode.dark ? 'dark' : 'light';

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: user.email)
          .get();

      if (userQuery.docs.isNotEmpty) {
        await userQuery.docs.first.reference.update({'themeMode': themeStr});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (user != null) {
          // Listen to the authenticated user's Firestore doc to load their saved theme
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Users')
                .where('email', isEqualTo: user.email)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                final userData = userSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                final savedTheme = userData['themeMode'] as String? ?? 'light';
                
                // Set notifier value matching user preference
                final targetMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
                if (themeNotifier.value != targetMode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    themeNotifier.value = targetMode;
                  });
                }
              }

              return _buildMaterialApp(home: const MainLayout());
            },
          );
        }

        return _buildMaterialApp(home: const AuthPage());
      },
    );
  }

  Widget _buildMaterialApp({required Widget home}) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Scavenger',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: home,
        );
      },
    );
  }
}