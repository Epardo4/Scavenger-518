import 'package:flutter/material.dart';
import 'tmdb_service.dart';
import 'models/search_result.dart';
import 'media_details_page.dart';
import 'media.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

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

  // Filter States
  String _selectedMediaType = 'ALL'; // 'ALL', 'MOVIE', 'TV'
  int? _selectedGenreId; // null means all genres

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  void _loadGenres() async {
    final genres = await _apiService.getGenreMap();
    if (mounted) {
      setState(() {
        _genreMap = genres;
      });
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
      _selectedGenreId = null; // Reset genre filter on new search
    });

    try {
      final results = await _apiService.searchTitles(query, _genreMap);
      setState(() {
        _allResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Filter results client-side
  List<SearchResult> get _filteredResults {
    return _allResults.where((item) {
      // Media Type Filter
      if (_selectedMediaType != 'ALL' && item.type != _selectedMediaType) {
        return false;
      }
      // Genre Filter
      if (_selectedGenreId != null && !item.genreIds.contains(_selectedGenreId)) {
        return false;
      }
      return true;
    }).toList();
  }

  // Extract list of unique genres present in the current search results
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
          // --- Search Bar ---
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

          // --- Filters Bar (Shown after search) ---
          if (_hasSearched && !_isLoading && _allResults.isNotEmpty) ...[
            _buildFilterSection(),
            const Divider(height: 1),
          ],

          // --- Results View ---
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
          // Media Type Segment Selector
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
            // Horizontal Genre Chips
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

    return ListView.builder(
      itemCount: filteredList.length,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemBuilder: (context, index) {
        final result = filteredList[index];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
          onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaDetailsPage(
                          mediaId: result.id,
                          // Convert the String ('MOVIE' / 'TV') to MediaType enum
                          mediaType: result.type.toUpperCase() == 'MOVIE'
                              ? MediaType.movie
                              : MediaType.tv,
                        ),
                      ),
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Poster Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 90,
                      child: result.imageUrl.isNotEmpty
                          ? Image.network(
                              result.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.movie, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.movie, color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Metadata & Genres
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Media Type & Year Badges
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: result.type == 'MOVIE'
                                    ? Colors.blue[50]
                                    : Colors.purple[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                result.type,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: result.type == 'MOVIE'
                                      ? Colors.blue[800]
                                      : Colors.purple[800],
                                ),
                              ),
                            ),
                            if (result.year != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${result.year}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Genre Tag Chips
                        if (result.genreNames.isNotEmpty)
                          Text(
                            result.genreNames.join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}