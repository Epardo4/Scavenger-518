import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Models/media.dart';
import 'tmdb_service.dart';
import 'episodes.dart';
import 'ratings.dart';
import 'streaming_services.dart';

class MediaDetailsPage extends StatefulWidget {
  final int mediaId;
  final MediaType mediaType;

  const MediaDetailsPage({
    super.key,
    required this.mediaId,
    required this.mediaType,
  });

  @override
  State<MediaDetailsPage> createState() => _MediaDetailsPageState();
}

class _MediaDetailsPageState extends State<MediaDetailsPage> {
  final TmdbService _tmdbService = TmdbService();

  Map<String, dynamic>? _media;
  bool _isLoading = true;
  String? _errorMessage;

  // Custom Firebase Rating State
  double? _firebaseAverageRating;
  int _firebaseRatingCount = 0;
  double? _userExistingRating; // Tracks what the current user previously rated it

  bool get _isMovie => widget.mediaType == MediaType.movie;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _loadFirebaseRating();
  }

  Future<void> _loadMedia() async {
    try {
      final data = _isMovie
          ? await _tmdbService.getMovieDetails(widget.mediaId)
          : await _tmdbService.getTvDetails(widget.mediaId);

      if (!mounted) return;

      setState(() {
        _media = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load this title.';
      });
    }
  }

  Future<void> _loadFirebaseRating() async {
    try {
      final docId = '${widget.mediaType.name}_${widget.mediaId}';
      final firestore = FirebaseFirestore.instance;

      // 1. Load global media rating
      final doc = await firestore.collection('MediaRatings').doc(docId).get();

      if (doc.exists && mounted) {
        setState(() {
          _firebaseAverageRating =
              (doc.data()?['averageRating'] as num?)?.toDouble();
          _firebaseRatingCount =
              (doc.data()?['ratingCount'] as num?)?.toInt() ?? 0;
        });
      }

      // 2. Load current user's specific rating for this title, if logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRatingDoc = await firestore
            .collection('Users')
            .doc(user.uid)
            .collection('Ratings')
            .doc(docId)
            .get();

        if (userRatingDoc.exists && mounted) {
          setState(() {
            _userExistingRating =
                (userRatingDoc.data()?['rating'] as num?)?.toDouble();
          });
        }
      }
    } catch (_) {
      // Fail silently if offline or uninitialized
    }
  }

  Future<void> _submitRating(double userRating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to rate titles.')),
      );
      return;
    }

    final docId = '${widget.mediaType.name}_${widget.mediaId}';
    final mediaRatingRef =
        FirebaseFirestore.instance.collection('MediaRatings').doc(docId);
    final userRatingRef = FirebaseFirestore.instance
        .collection('Users')
        .doc(user.uid)
        .collection('Ratings')
        .doc(docId);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitting rating...')),
      );

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final mediaSnapshot = await transaction.get(mediaRatingRef);

        double currentAvg;
        int currentCount;
        final tmdbAvg = (_media?['vote_average'] as num? ?? 0.0).toDouble();

        if (mediaSnapshot.exists) {
          currentAvg = (mediaSnapshot.data()?['averageRating'] ?? 0.0).toDouble();
          currentCount = (mediaSnapshot.data()?['ratingCount'] ?? 1).toInt();
        } else {
          currentAvg = tmdbAvg;
          currentCount = 1;
        }

        double newAvg;
        int newCount;

        if (_userExistingRating != null) {
          // --- CASE 1: Updating an existing rating ---
          // Formula: ((averageRating * ratingCount) - oldUsrRating + newRating) / ratingCount
          // No need to update the rating count in this scenario.
          if (currentCount > 0) {
            newAvg = ((currentAvg * currentCount) - _userExistingRating! + userRating) /
                currentCount;
          } else {
            newAvg = userRating;
          }
          newCount = currentCount;
        } else {
          // --- CASE 2: Submitting a new rating ---
          newAvg = ((currentAvg * currentCount) + userRating) / (currentCount + 1);
          newCount = currentCount + 1;
        }

        // Update global media rating document
        transaction.set(
          mediaRatingRef,
          {
            'averageRating': newAvg,
            'ratingCount': newCount,
          },
          SetOptions(merge: true),
        );

        // Save/Update user's personal rating record
        String title = 'Unknown title';
        if (_media != null) {
          if (widget.mediaType == MediaType.movie) {
            title = _media!['title'] ?? 'Unknown title';
          } else {
            title = _media!['name'] ?? 'Unknown title';
          }
        }

        String? posterPath;
        if (_media != null) {
          posterPath = _media!['poster_path'] as String?;
        }

        transaction.set(
          userRatingRef,
          {
            'mediaId': widget.mediaId,
            'mediaType': widget.mediaType.name,
            'title': title,
            'posterPath': posterPath ?? '',
            'rating': userRating,
            'timestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          userRatingRef,
          {
            'mediaId': widget.mediaId,
            'mediaType': widget.mediaType.name,
            'title': title,
            'posterPath': posterPath ?? '',
            'rating': userRating,
            'timestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        if (mounted) {
          setState(() {
            _firebaseAverageRating = newAvg;
            _firebaseRatingCount = newCount;
            _userExistingRating = userRating;
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    }
  }

  void _showRatingDialog() {
    int selectedRating = _userExistingRating?.round() ?? 5;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_userExistingRating != null ? 'Update Your Rating' : 'Rate this Title'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_userExistingRating != null
                      ? 'Change your rating (1-10 stars):'
                      : 'Select your rating (1-10 stars):'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '$selectedRating / 10',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedRating.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: selectedRating.toString(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRating = value.round();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitRating(selectedRating.toDouble());
              },
              child: Text(_userExistingRating != null ? 'Update' : 'Submit'),
            ),
          ],
        );
      },
    );
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _loadMedia();
    _loadFirebaseRating();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMovie ? 'Movie Details' : 'TV Show Details'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _retry, child: const Text('Try Again')),
          ],
        ),
      );
    }

    if (_media == null) {
      return const Center(child: Text('No information available.'));
    }

    return _buildDetails();
  }

  Widget _buildDetails() {
    final media = _media!;
    final title = _isMovie
        ? media['title'] ?? 'Unknown title'
        : media['name'] ?? 'Unknown title';
    final overview = (media['overview'] as String?)?.trim() ?? '';
    final posterPath = media['poster_path'] as String?;
    final backdropPath = media['backdrop_path'] as String?;
    
    final displayRating = _firebaseAverageRating ?? (media['vote_average'] as num? ?? 0).toDouble();

    final releaseDate = _isMovie
        ? media['release_date'] as String? ?? ''
        : media['first_air_date'] as String? ?? '';
    final genres =
        (media['genres'] as List?)
            ?.map((genre) => genre['name'].toString())
            .toList() ??
        [];
    final cast = (media['credits']?['cast'] as List?)?.take(10).toList() ?? [];
    final streamingServices = media['watch/providers'] as Map<String, dynamic>?;
    final seasons = (media['seasons'] as List?) ?? [];


    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackdrop(backdropPath),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPosterAndTitle(posterPath, title, displayRating),
                const SizedBox(height: 25),
                _buildBasicInformation(releaseDate, _getRuntime()),
                const SizedBox(height: 25),
                
                // Rate Button above overview
                _buildRateButton(),
                const SizedBox(height: 25),

                _buildSection(
                  title: 'Overview',
                  child: Text(
                    overview.isEmpty ? 'No overview available.' : overview,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSection(title: 'Genres', child: _buildGenres(genres)),
                const SizedBox(height: 20),
                _buildSection(title: 'Cast', child: _buildCast(cast)),
                const SizedBox(height: 25),
                _buildWatchlistButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdrop(String? backdropPath) {
    if (backdropPath == null || backdropPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 220,
      child: Image.network(
        'https://image.tmdb.org/t/p/w780$backdropPath',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPosterAndTitle(String? posterPath, String title, double rating) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPoster(posterPath),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 22),
                  const SizedBox(width: 5),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(' / 10', style: TextStyle(fontSize: 16)),
                ],
              ),
              if (_firebaseRatingCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '($_firebaseRatingCount community ratings)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (_userExistingRating != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Your Rating: ${_userExistingRating!.toStringAsFixed(0)} / 10',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoster(String? posterPath) {
    if (posterPath == null || posterPath.isEmpty) {
      return _posterPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        'https://image.tmdb.org/t/p/w500$posterPath',
        width: 130,
        height: 195,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _posterPlaceholder(),
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      width: 130,
      height: 195,
      color: Colors.grey[300],
      child: const Icon(Icons.movie, size: 50),
    );
  }

  Widget _buildBasicInformation(String releaseDate, String runtime) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (releaseDate.isNotEmpty)
          _InfoChip(icon: Icons.calendar_today, text: releaseDate),
        if (runtime.isNotEmpty) _InfoChip(icon: Icons.schedule, text: runtime),
        _InfoChip(
          icon: _isMovie ? Icons.movie : Icons.tv,
          text: _isMovie ? 'Movie' : 'TV Show',
        ),
      ],
    );
  }

  String _getRuntime() {
    final media = _media!;

    if (_isMovie) {
      final runtime = media['runtime'];
      if (runtime is! int) return '';

      final hours = runtime ~/ 60;
      final minutes = runtime % 60;
      if (hours > 0) return '${hours}h ${minutes}m';
      return '${minutes}m';
    }

    final episodeRunTime = media['episode_run_time'];
    if (episodeRunTime is List && episodeRunTime.isNotEmpty) {
      return '${episodeRunTime.first}m/episode';
    }

    return '';
  }

  Widget _buildGenres(List<String> genres) {
    if (genres.isEmpty) {
      return const Text('No genres available.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((genre) => Chip(label: Text(genre))).toList(),
    );
  }

  Widget _buildCast(List<dynamic> cast) {
    if (cast.isEmpty) {
      return const Text('Cast information unavailable.');
    }

    return Column(
      children: cast.map((person) {
        final name = person['name'] ?? 'Unknown';
        final character = person['character'] ?? '';
        final profilePath = person['profile_path'] as String?;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _buildProfileImage(profilePath),
          title: Text(name),
          subtitle: character.isEmpty ? null : Text(character),
        );
      }).toList(),
    );
  }

  Widget _buildProfileImage(String? profilePath) {
    if (profilePath == null || profilePath.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.person));
    }

    return CircleAvatar(
      radius: 25,
      backgroundImage: NetworkImage(
        'https://image.tmdb.org/t/p/w185$profilePath',
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildRateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _showRatingDialog,
        icon: const Icon(Icons.star_rate),
        label: Text(
          _userExistingRating != null ? 'Update Your Rating' : 'Rate this Title',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber[700],
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWatchlistButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watchlist functionality coming soon!'),
            ),
          );
        },
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Add to Watchlist', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 17), label: Text(text));
  }
}