import 'package:flutter/material.dart';
import 'tmdb_service.dart';
import 'Models/media.dart';
import 'media_details_page.dart';

class ActorDetailsPage extends StatefulWidget {
  final int personId;

  const ActorDetailsPage({super.key, required this.personId});

  @override
  State<ActorDetailsPage> createState() => _ActorDetailsPageState();
}

class _ActorDetailsPageState extends State<ActorDetailsPage> {
  final TmdbService _tmdbService = TmdbService();
  Map<String, dynamic>? _personData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPersonDetails();
  }

  Future<void> _loadPersonDetails() async {
    try {
      final data = await _tmdbService.getPersonDetails(widget.personId);
      if (!mounted) return;
      setState(() {
        _personData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load actor details.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_personData?['name'] ?? 'Actor Details'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _personData == null) {
      return Center(child: Text(_errorMessage ?? 'No information available.'));
    }

    final person = _personData!;
    final name = person['name'] ?? 'Unknown';
    final biography = person['biography'] ?? 'No biography available.';
    final profilePath = person['profile_path'] as String?;
    final profileUrl = profilePath != null && profilePath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500$profilePath'
        : '';

    final credits = (person['combined_credits']?['cast'] as List<dynamic>?) ?? [];
    
    // Sort credits by release/air date descending
    credits.sort((a, b) {
      final dateA = a['release_date'] ?? a['first_air_date'] ?? '';
      final dateB = b['release_date'] ?? b['first_air_date'] ?? '';
      return dateB.compareTo(dateA);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 120,
                  height: 180,
                  child: profileUrl.isNotEmpty
                      ? Image.network(
                          profileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _profilePlaceholder(),
                        )
                      : _profilePlaceholder(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (person['known_for_department'] != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Department: ${person['known_for_department']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                    if (person['place_of_birth'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Born: ${person['place_of_birth']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Biography',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            biography.isEmpty ? 'No biography available.' : biography,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Filmography',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCreditsList(credits),
        ],
      ),
    );
  }

  Widget _profilePlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.person, size: 50, color: Colors.grey),
    );
  }

  Widget _buildCreditsList(List<dynamic> credits) {
    if (credits.isEmpty) {
      return const Text('No filmography available.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: credits.length,
      itemBuilder: (context, index) {
        final credit = credits[index];
        final mediaTypeStr = credit['media_type'] ?? 'movie';
        if (mediaTypeStr != 'movie' && mediaTypeStr != 'tv') return const SizedBox.shrink();

        final mediaId = credit['id'];
        final title = credit['title'] ?? credit['name'] ?? 'Unknown Title';
        
        // Handle role fallback: if null or empty, display 'Uncredited'
        final rawCharacter = credit['character'];
        final character = (rawCharacter == null || rawCharacter.toString().trim().isEmpty)
            ? 'Uncredited'
            : rawCharacter.toString();

        final posterPath = credit['poster_path'] as String?;
        final posterUrl = posterPath != null && posterPath.isNotEmpty
            ? 'https://image.tmdb.org/t/p/w185$posterPath'
            : '';
        final releaseDate = credit['release_date'] ?? credit['first_air_date'] ?? '';
        final year = releaseDate.isNotEmpty ? releaseDate.split('-')[0] : '';

        final mediaType = mediaTypeStr == 'tv' ? MediaType.tv : MediaType.movie;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 50,
                height: 75,
                child: posterUrl.isNotEmpty
                    ? Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _posterPlaceholder(),
                      )
                    : _posterPlaceholder(),
              ),
            ),
            title: Text(
              title + (year.isNotEmpty ? ' ($year)' : ''),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'Role: $character',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MediaDetailsPage(
                    mediaId: mediaId,
                    mediaType: mediaType,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.movie, size: 24, color: Colors.grey),
    );
  }
}