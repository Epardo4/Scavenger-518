import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tmdb_service.dart';
import 'Models/search_result.dart';
import 'media_details_page.dart';
import 'Models/media.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({Key? key, this.initialQuery}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TmdbService _apiService = TmdbService();
  final TextEditingController _searchController = TextEditingController();

  Map<int, String> _genreMap = {};
  List<SearchResult> _allResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  String _selectedMediaType = 'ALL'; 
  int? _selectedGenreId;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
    }
    _loadGenres();
  }

  void _loadGenres() async {
    final genres = await _apiService.getGenreMap();
    if (mounted) {
      setState(() {
        _genreMap = genres;
      });

      if (_searchController.text.trim().isNotEmpty && !_hasSearched) {
        _performSearch();
      }
    }
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
      _selectedGenreId = null;
    });

    try {
      final results = await _apiService.searchTitles(query, _genreMap);
      if (mounted) {
        setState(() {
          _allResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<SearchResult> get _filteredResults {
    return _allResults.where((item) {
      if (_selectedMediaType != 'ALL' && item.type != _selectedMediaType) {
        return false;
      }
      if (_selectedGenreId != null && !item.genreIds.contains(_selectedGenreId)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<MapEntry<int, String>> get _availableResultGenres {
    final Set<int> presentGenreIds = {};
    for (var item in _allResults) {
      presentGenreIds.addAll(item.genreIds);
    }
    return _genreMap.entries
        .where((entry) => presentGenreIds.contains(entry.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Movies & TV Shows'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search title (e.g. Inception, Breaking Bad)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _allResults = [];
                      _hasSearched = false;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_hasSearched && !_isLoading && _allResults.isNotEmpty) ...[
            _buildFilterSection(),
            const Divider(height: 1),
          ],

          Expanded(
            child: _buildResultsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    final availableGenres = _availableResultGenres;

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedMediaType == 'ALL',
                  onSelected: (_) => setState(() => _selectedMediaType = 'ALL'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('Movies'),
                  selected: _selectedMediaType == 'MOVIE',
                  onSelected: (_) => setState(() => _selectedMediaType = 'MOVIE'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('TV Shows'),
                  selected: _selectedMediaType == 'TV',
                  onSelected: (_) => setState(() => _selectedMediaType = 'TV'),
                ),
              ],
            ),
          ),

          if (availableGenres.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: availableGenres.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: const Text('All Genres'),
                        selected: _selectedGenreId == null,
                        onSelected: (_) => setState(() => _selectedGenreId = null),
                      ),
                    );
                  }

                  final genre = availableGenres[index - 1];
                  final isSelected = _selectedGenreId == genre.key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(genre.value),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedGenreId = selected ? genre.key : null;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Type a title above and tap Search',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    final filteredList = _filteredResults;

    if (filteredList.isEmpty) {
      return const Center(
        child: Text(
          'No titles match the selected filters.',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    double screenWidth = MediaQuery.sizeOf(context).width;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: (screenWidth/120).floor(),
        childAspectRatio: 0.52,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final result = filteredList[index];

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaDetailsPage(
                  mediaId: result.id,
                  mediaType: result.type.toUpperCase() == 'MOVIE'
                      ? MediaType.movie
                      : MediaType.tv,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: result.imageUrl.isNotEmpty
                            ? Image.network(
                                result.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _posterPlaceholder(),
                              )
                            : _posterPlaceholder(),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: FirebaseRatingBadge(
                        mediaId: result.id,
                        mediaType: result.type.toLowerCase(),
                        tmdbRating: result.rating,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.movie, size: 40, color: Colors.grey),
      ),
    );
  }
}

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