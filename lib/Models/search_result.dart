class SearchResult {
  final int id;
  final String name;
  final String type;
  final int? year;
  final String imageUrl;
  final List<int> genreIds;
  List<String> genreNames;

  SearchResult({
    required this.id,
    required this.name,
    required this.type,
    this.year,
    required this.imageUrl,
    required this.genreIds,
    this.genreNames = const [],
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final mediaType = (json['media_type'] ?? 'movie').toString().toUpperCase();
    final title = json['title'] ?? json['name'] ?? 'Unknown Title';
    int? parsedYear;
    final releaseDate = json['release_date'] ?? json['first_air_date'];
    if (releaseDate != null && releaseDate.toString().isNotEmpty) {
      final parts = releaseDate.toString().split('-');
      if (parts.isNotEmpty) {
        parsedYear = int.tryParse(parts[0]);
      }
    }
    final posterPath = json['poster_path'];
    final fullImageUrl = (posterPath != null && posterPath.toString().isNotEmpty)
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : '';
    List<int> parsedGenreIds = [];
    if (json['genre_ids'] != null && json['genre_ids'] is List) {
      parsedGenreIds = List<int>.from(json['genre_ids']);
    }

    return SearchResult(
      id: json['id'] ?? 0,
      name: title,
      type: mediaType,
      year: parsedYear,
      imageUrl: fullImageUrl,
      genreIds: parsedGenreIds,
    );
  }
}