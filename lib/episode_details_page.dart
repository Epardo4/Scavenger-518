import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tmdb_service.dart';

class EpisodeDetailsPage extends StatefulWidget {
  final int tvId;
  final int seasonNumber;
  final int episodeNumber;

  const EpisodeDetailsPage({
    super.key,
    required this.tvId,
    required this.seasonNumber,
    required this.episodeNumber,
  });

  @override
  State<EpisodeDetailsPage> createState() => _EpisodeDetailsPageState();
}

class _EpisodeDetailsPageState extends State<EpisodeDetailsPage> {
  final TmdbService _tmdbService = TmdbService();
  Map<String, dynamic>? _episodeData;
  bool _isLoading = true;
  String? _errorMessage;

  // Custom Firebase Rating State
  double? _firebaseAverageRating;
  int _firebaseRatingCount = 0;
  double? _userExistingRating;

  @override
  void initState() {
    super.initState();
    _loadEpisodeDetails();
    _loadFirebaseRating();
  }

  Future<void> _loadEpisodeDetails() async {
    try {
      final seasonData = await _tmdbService.getSeasonDetails(widget.tvId, widget.seasonNumber);
      final episodes = seasonData['episodes'] as List<dynamic>? ?? [];
      
      final episode = episodes.firstWhere(
        (e) => e['episode_number'] == widget.episodeNumber,
        orElse: () => null,
      );

      if (!mounted) return;

      if (episode != null) {
        setState(() {
          _episodeData = episode;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Episode not found.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load episode details.';
      });
    }
  }

  Future<void> _loadFirebaseRating() async {
    try {
      final docId = 'tv_${widget.tvId}_s${widget.seasonNumber}_e${widget.episodeNumber}';
      final firestore = FirebaseFirestore.instance;

      // 1. Load global episode rating
      final doc = await firestore.collection('MediaRatings').doc(docId).get();

      if (doc.exists && mounted) {
        setState(() {
          _firebaseAverageRating = (doc.data()?['averageRating'] as num?)?.toDouble();
          _firebaseRatingCount = (doc.data()?['ratingCount'] as num?)?.toInt() ?? 0;
        });
      }

      // 2. Load current user's specific rating for this episode
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
            _userExistingRating = (userRatingDoc.data()?['rating'] as num?)?.toDouble();
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
        const SnackBar(content: Text('You must be logged in to rate episodes.')),
      );
      return;
    }

    final docId = 'tv_${widget.tvId}_s${widget.seasonNumber}_e${widget.episodeNumber}';
    final mediaRatingRef = FirebaseFirestore.instance.collection('MediaRatings').doc(docId);
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
        final tmdbAvg = (_episodeData?['vote_average'] as num? ?? 0.0).toDouble();

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
          if (currentCount > 0) {
            newAvg = ((currentAvg * currentCount) - _userExistingRating! + userRating) / currentCount;
          } else {
            newAvg = userRating;
          }
          newCount = currentCount;
        } else {
          newAvg = ((currentAvg * currentCount) + userRating) / (currentCount + 1);
          newCount = currentCount + 1;
        }

        // Update global rating document
        transaction.set(
          mediaRatingRef,
          {
            'averageRating': newAvg,
            'ratingCount': newCount,
          },
          SetOptions(merge: true),
        );

        // Save user's personal rating record
        final epName = _episodeData?['name'] ?? 'Episode ${widget.episodeNumber}';
        final title = 'S${widget.seasonNumber} E${widget.episodeNumber}: $epName';
        final stillPath = _episodeData?['still_path'] as String? ?? '';

        transaction.set(
          userRatingRef,
          {
            'mediaId': widget.tvId,
            'mediaType': 'tv',
            'seasonNumber': widget.seasonNumber,
            'episodeNumber': widget.episodeNumber,
            'title': title,
            'posterPath': stillPath,
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
        const SnackBar(content: Text('Episode rating submitted successfully!')),
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
          title: Text(_userExistingRating != null ? 'Update Episode Rating' : 'Rate this Episode'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Season ${widget.seasonNumber} • Episode ${widget.episodeNumber}'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _episodeData == null) {
      return Center(child: Text(_errorMessage ?? 'No information available.'));
    }

    final episode = _episodeData!;
    final name = episode['name'] ?? 'Unknown Episode';
    final overview = episode['overview'] ?? 'No overview available.';
    final airDate = episode['air_date'] ?? '';
    
    final displayRating = _firebaseAverageRating ?? (episode['vote_average'] as num? ?? 0.0).toDouble();
    
    final stillPath = episode['still_path'] as String?;
    final stillUrl = stillPath != null && stillPath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w780$stillPath'
        : '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stillUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Image.network(
                stillUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      displayRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(' / 10', style: TextStyle(fontSize: 14)),
                    if (_firebaseRatingCount > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '($_firebaseRatingCount)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    if (airDate.isNotEmpty) ...[
                      const SizedBox(width: 20),
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(airDate, style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
                if (_userExistingRating != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Your Rating: ${_userExistingRating!.toStringAsFixed(0)} / 10',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                
                // Rate Episode Button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _showRatingDialog,
                    icon: const Icon(Icons.star_rate),
                    label: Text(
                      _userExistingRating != null ? 'Update Episode Rating' : 'Rate this Episode',
                      style: const TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  overview.isEmpty ? 'No overview available.' : overview,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}