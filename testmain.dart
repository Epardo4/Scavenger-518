import 'package:flutter/material.dart';

import 'media.dart';
import 'media_details_page.dart';

void main() {
  runApp(const MovieApp());
}

class MovieApp extends StatelessWidget {
  const MovieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const MediaDetailsPage(
        mediaId: 634649,
        mediaType: MediaType.movie,
      ),
    );
  }
}