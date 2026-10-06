import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'auth_page.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scavenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // 2. StreamBuilder listens for auth changes
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading spinner while checking auth status on app start
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If the user is logged in, show HomePage
          if (snapshot.hasData) {
            return const HomePage();
          }

          // Otherwise, show AuthPage
          return const AuthPage();
        },
      ),
    );
  }
}
// class MovieSearchPage extends StatefulWidget {
//   const MovieSearchPage({super.key});

//   @override
//   State<MovieSearchPage> createState() => _MovieSearchPageState();
// }

// class _MovieSearchPageState extends State<MovieSearchPage> {
//   final TmdbService _tmdbService = TmdbService();
//   final TextEditingController _queryController = TextEditingController();

//   List<Media> _results = [];
//   bool _isLoading = false;
//   String? _errorMessage;
//   bool _hasSearched = false;

//   @override
//   void dispose() {
//     _queryController.dispose();
//     super.dispose();
//   }

//   Future<void> _search() async {
//     final query = _queryController.text.trim();
//     if (query.isEmpty) {
//       setState(() {
//         _results = [];
//         _errorMessage = null;
//         _hasSearched = false;
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//       _hasSearched = true;
//     });

//     try {
//       final results = await _tmdbService.searchMoviesAndTvShows(query);
//       if (!mounted) return;
//       setState(() {
//         _results = results;
//         _isLoading = false;
//       });
//     } catch (_) {
//       if (!mounted) return;
//       setState(() {
//         _results = [];
//         _isLoading = false;
//         _errorMessage = 'Unable to load results from the movie database.';
//       });
//     }
//   }

//   void _openDetails(Media media) {
//     Navigator.of(context).push(
//       MaterialPageRoute<void>(
//         builder: (context) =>
//             MediaDetailsPage(mediaId: media.id, mediaType: media.type),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Movie Search')),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _queryController,
//                     textInputAction: TextInputAction.search,
//                     decoration: const InputDecoration(
//                       labelText: 'Search movies and TV shows',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.search),
//                     ),
//                     onSubmitted: (_) => _search(),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 FilledButton(
//                   onPressed: _isLoading ? null : _search,
//                   child: const Text('Search'),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(child: _buildResults()),
//         ],
//       ),
//     );
//   }

//   Widget _buildResults() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Text(_errorMessage!, textAlign: TextAlign.center),
//         ),
//       );
//     }

//     if (!_hasSearched) {
//       return const Center(
//         child: Text('Search the movie database to see a title.'),
//       );
//     }

//     if (_results.isEmpty) {
//       return const Center(
//         child: Text('No movies or TV shows matched that search.'),
//       );
//     }

//     return ListView.separated(
//       itemCount: _results.length,
//       separatorBuilder: (context, index) => const Divider(height: 1),
//       itemBuilder: (context, index) {
//         final media = _results[index];
//         final year = media.releaseDate.length >= 4
//             ? media.releaseDate.substring(0, 4)
//             : '';

//         return ListTile(
//           leading: _poster(media),
//           title: Text(media.title),
//           subtitle: Text(
//             [
//               media.type == MediaType.movie ? 'Movie' : 'TV Show',
//               if (year.isNotEmpty) year,
//               media.rating.toStringAsFixed(1),
//             ].join(' · '),
//           ),
//           onTap: () => _openDetails(media),
//         );
//       },
//     );
//   }

//   Widget _poster(Media media) {
//     if (media.posterUrl.isEmpty) {
//       return const SizedBox(width: 40, height: 60, child: Icon(Icons.movie));
//     }

//     return ClipRRect(
//       borderRadius: BorderRadius.circular(4),
//       child: Image.network(
//         media.posterUrl,
//         width: 40,
//         height: 60,
//         fit: BoxFit.cover,
//         errorBuilder: (context, error, stackTrace) =>
//             const SizedBox(width: 40, height: 60, child: Icon(Icons.movie)),
//       ),
//     );
//   }
//}
