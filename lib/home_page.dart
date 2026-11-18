import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tmdb_service.dart';
import 'Models/media.dart';
import 'media_details_page.dart';
import 'search_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TmdbService _tmdbService = TmdbService();
  final TextEditingController _homeSearchController = TextEditingController();

  int currentPage = 0;

  List<Media> _topMovies = [];
  List<Media> _topTvShows = [];
  List<Media> _friendsPopularMedia = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHomePageData();
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadHomePageData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _tmdbService.getTopRatedMovies(),
        _tmdbService.getTopRatedTvShows(),
        _loadFriendsPopularMedia(),
      ]);

      if (!mounted) return;

      setState(() {
        _topMovies = results[0];
        _topTvShows = results[1];
        _friendsPopularMedia = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load home page content.';
      });
    }
  }

  Future<List<Media>> _loadFriendsPopularMedia() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final db = FirebaseFirestore.instance;
      final friendSnap = await db.collection('Users').doc(user.uid).collection('Friends').get();
      if (friendSnap.docs.isEmpty) return [];

      final friendUids = friendSnap.docs.map((d) => d.id).toList();
      final Map<String, Media> uniqueMediaMap = {};

      for (final friendUid in friendUids) {
        final ratingsSnap = await db
            .collection('Users')
            .doc(friendUid)
            .collection('Ratings')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        for (final doc in ratingsSnap.docs) {
          final data = doc.data();
          if (data['seasonNumber'] != null) continue;

          final mediaId = (data['mediaId'] as num?)?.toInt();
          final mediaTypeStr = data['mediaType'] as String? ?? 'movie';
          final title = data['title'] as String? ?? 'Unknown Title';
          final posterPath = data['posterPath'] as String? ?? '';
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

          if (mediaId != null && !uniqueMediaMap.containsKey('${mediaTypeStr}_$mediaId')) {
            final mediaType = mediaTypeStr == 'tv' ? MediaType.tv : MediaType.movie;
            uniqueMediaMap['${mediaTypeStr}_$mediaId'] = Media(
              id: mediaId,
              title: title,
              posterPath: posterPath,
              overview: '',
              rating: rating,
              releaseDate: '',
              type: mediaType,
            );
          }
        }
      }

      final mediaList = uniqueMediaMap.values.toList();
      mediaList.shuffle();
      return mediaList;
    } catch (_) {
      return [];
    }
  }

  Future<void> logOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _navigateToSearch(BuildContext context, {String? initialQuery}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialQuery: initialQuery),
      ),
    );
  }

  void _navigateToDetails(Media media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaDetailsPage(
          mediaId: media.id,
          mediaType: media.type,
        ),
      ),
    );
  }

  void _handleHomeSearchSubmit() {
    final query = _homeSearchController.text.trim();
    if (query.isNotEmpty) {
      _navigateToSearch(context, initialQuery: query);
    } else {
      _navigateToSearch(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHomePageData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade700, Colors.purple.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome Back!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'Scavenger User',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Interactive Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _homeSearchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _handleHomeSearchSubmit(),
                  decoration: InputDecoration(
                    hintText: 'Search movies & TV shows...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _handleHomeSearchSubmit,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[850] 
                        : Colors.grey.shade100,
                    prefixIcon: Icon(
                      Icons.search, 
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Content Lists
              if (_isLoading)
                const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadHomePageData,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Popular Among Friends Section
                if (_friendsPopularMedia.isNotEmpty) ...[
                  _buildSectionHeader('Popular Among Friends', Icons.people_outline),
                  const SizedBox(height: 12),
                  _buildHorizontalMediaList(_friendsPopularMedia, showRank: false),
                  const SizedBox(height: 28),
                ],

                // Top 10 Movies
                _buildSectionHeader('Top 10 Movies', Icons.movie_outlined),
                const SizedBox(height: 12),
                _buildHorizontalMediaList(_topMovies, showRank: true),

                const SizedBox(height: 28),

                // Top 10 TV Shows
                _buildSectionHeader('Top 10 TV Shows', Icons.tv_outlined),
                const SizedBox(height: 12),
                _buildHorizontalMediaList(_topTvShows, showRank: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalMediaList(List<Media> items, {bool showRank = true}) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final media = items[index];
          return Container(
            width: 130,
            margin: const EdgeInsets.only(right: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _navigateToDetails(media),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: media.posterUrl.isNotEmpty
                            ? Image.network(
                                media.posterUrl,
                                height: 180,
                                width: 130,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _posterPlaceholder(),
                              )
                            : _posterPlaceholder(),
                      ),
                      if (showRank)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: FirebaseRatingBadge(
                          mediaId: media.id,
                          mediaType: media.type == MediaType.movie ? 'movie' : 'tv',
                          tmdbRating: media.rating,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      height: 180,
      width: 130,
      color: Colors.grey.shade300,
      child: const Icon(Icons.movie, size: 40, color: Colors.grey),
    );
  }
}

/// Reusable widget to load and display Firebase rating with fallback to TMDB
class FirebaseRatingBadge extends StatelessWidget {
  final int mediaId;
  final String mediaType; // 'movie' or 'tv'
  final double tmdbRating;

  const FirebaseRatingBadge({
    super.key,
    required this.mediaId,
    required this.mediaType,
    required this.tmdbRating,
  });

  @override
  Widget build(BuildContext context) {
    final docId = '${mediaType.toLowerCase()}_$mediaId';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('MediaRatings').doc(docId).get(),
      builder: (context, snapshot) {
        double displayRating = tmdbRating;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('averageRating')) {
            displayRating = (data['averageRating'] as num).toDouble();
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star,
                color: Colors.amber,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                displayRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}