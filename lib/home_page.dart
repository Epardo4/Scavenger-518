import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tmdb_service.dart';
import 'Models/media.dart';
import 'media_details_page.dart';
import 'search_screen.dart';
import 'profile_page.dart';

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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTopRatedContent();
  }

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTopRatedContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _tmdbService.getTopRatedMovies(),
        _tmdbService.getTopRatedTvShows(),
      ]);

      if (!mounted) return;

      setState(() {
        _topMovies = results[0];
        _topTvShows = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load top rated content.';
      });
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
      appBar: AppBar(
        title: const Text('Scavenger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => _navigateToSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: logOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTopRatedContent,
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
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _handleHomeSearchSubmit,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
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
                          onPressed: _loadTopRatedContent,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Top 10 Movies
                _buildSectionHeader('Top 10 Movies', Icons.movie_outlined),
                const SizedBox(height: 12),
                _buildHorizontalMediaList(_topMovies),

                const SizedBox(height: 28),

                // Top 10 TV Shows
                _buildSectionHeader('Top 10 TV Shows', Icons.tv_outlined),
                const SizedBox(height: 12),
                _buildHorizontalMediaList(_topTvShows),
              ],
            ],
          ),
        ),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentPage,
        onTap: (value) {
          setState(() {currentPage = value;});
          if(currentPage == 1){
            Navigator.push(
              context,MaterialPageRoute(builder: (context) => const ProfilePage())
          );}
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person),label: "Profile")
        ]
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

  Widget _buildHorizontalMediaList(List<Media> items) {
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
                                errorBuilder: (_, __, ___) => _posterPlaceholder(),
                              )
                            : _posterPlaceholder(),
                      ),
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
                        child: Container(
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
                                media.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
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
      color: Colors.grey[300],
      child: const Icon(Icons.movie, size: 40, color: Colors.grey),
    );
  }
}