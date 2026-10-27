import 'dart:convert';

import 'package:http/http.dart' as http;

import 'Models/media.dart';

import 'Models/search_result.dart';

class TmdbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  final String accessToken =
      'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI1N2Y2ZjQzYjc3OWE3N2JmMDU5NWYyM2QxZjkzMWU0MyIsIm5iZiI6MTc5MTE0MDcwNy4zMTIsInN1YiI6IjZhYzJhMzYzZGY3ZDdhZmUyYjJhNWRkMiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.Qyxl0GhOjesmW0kRLmVFeBMO6Y-iMOnaPn3IOHDc7IM';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      };

  Future<Map<int, String>> getGenreMap() async {
    Map<int, String> genreMap = {};

    try {
      final movieUrl = Uri.parse('$baseUrl/genre/movie/list');
      final tvUrl = Uri.parse('$baseUrl/genre/tv/list');

      final responses = await Future.wait([
        http.get(movieUrl, headers: _headers),
        http.get(tvUrl, headers: _headers),
      ]);

      for (var response in responses) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List genres = data['genres'] ?? [];
          for (var g in genres) {
            genreMap[g['id']] = g['name'];
          }
        }
      }
    } catch (_) {}

    return genreMap;
  }

  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final url = Uri.parse(
      '$baseUrl/movie/$movieId?language=en-US'
      '&append_to_response=credits,watch/providers', // <-- Added watch/providers
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load movie details: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getTvDetails(int tvId) async {
    final url = Uri.parse(
      '$baseUrl/tv/$tvId?language=en-US'
      '&append_to_response=credits,watch/providers', // <-- Added watch/providers
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load TV show details: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> getSeasonDetails(int tvId, int seasonNumber) async {
    final url = Uri.parse(
      '$baseUrl/tv/$tvId/season/$seasonNumber?language=en-US',
    );

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load season details: ${response.statusCode}');
  }

  Future<List<SearchResult>> searchTitles(
      String query, Map<int, String> genreMap) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('$baseUrl/search/multi?query=$encodedQuery');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];

        return results
            .where((item) =>
                item['media_type'] == 'movie' || item['media_type'] == 'tv')
            .map((item) {
              final result = SearchResult.fromJson(item);
              result.genreNames = result.genreIds
                  .map((id) => genreMap[id])
                  .whereType<String>()
                  .toList();
              return result;
            })
            .where((item) => item.id != 0)
            .toList();
      } else {
        throw Exception(
            'Failed to fetch search results (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error searching titles: $e');
    }
  }

  Future<List<Media>> searchMoviesAndTvShows(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final movieResults = await _searchMovies(query);
    final tvResults = await _searchTvShows(query);

    return [...movieResults, ...tvResults];
  }

  Future<List<Media>> _searchMovies(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse(
      '$baseUrl/search/movie'
      '?query=$encodedQuery'
      '&language=en-US'
      '&include_adult=false'
      '&page=1',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Movie search failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    final results = data['results'] as List;

    return results.map((movie) {
      return Media(
        id: movie['id'],
        title: movie['title'] ?? 'Unknown title',
        posterPath: movie['poster_path'] ?? '',
        overview: movie['overview'] ?? 'No overview available.',
        releaseDate: movie['release_date'] ?? '',
        rating: (movie['vote_average'] ?? 0).toDouble(),
        type: MediaType.movie,
      );
    }).toList();
  }

  Future<List<Media>> _searchTvShows(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);

    final url = Uri.parse(
      '$baseUrl/search/tv'
      '?query=$encodedQuery'
      '&language=en-US'
      '&include_adult=false'
      '&page=1',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('TV show search failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    final results = data['results'] as List;

    return results.map((tv) {
      return Media(
        id: tv['id'],
        title: tv['name'] ?? 'Unknown title',
        posterPath: tv['poster_path'] ?? '',
        overview: tv['overview'] ?? 'No overview available.',
        releaseDate: tv['first_air_date'] ?? '',
        rating: (tv['vote_average'] ?? 0).toDouble(),
        type: MediaType.tv,
      );
    }).toList();
  }

  Future<List<Media>> getTopRatedMovies() async {
    final url = Uri.parse('$baseUrl/movie/top_rated?language=en-US&page=1');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.take(10).map((movie) {
        return Media(
          id: movie['id'],
          title: movie['title'] ?? 'Unknown title',
          posterPath: movie['poster_path'] ?? '',
          overview: movie['overview'] ?? 'No overview available.',
          releaseDate: movie['release_date'] ?? '',
          rating: (movie['vote_average'] ?? 0).toDouble(),
          type: MediaType.movie,
        );
      }).toList();
    }
    throw Exception('Failed to load top rated movies');
  }

  Future<List<Media>> getTopRatedTvShows() async {
    final url = Uri.parse('$baseUrl/tv/top_rated?language=en-US&page=1');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      return results.take(10).map((tv) {
        return Media(
          id: tv['id'],
          title: tv['name'] ?? 'Unknown title',
          posterPath: tv['poster_path'] ?? '',
          overview: tv['overview'] ?? 'No overview available.',
          releaseDate: tv['first_air_date'] ?? '',
          rating: (tv['vote_average'] ?? 0).toDouble(),
          type: MediaType.tv,
        );
      }).toList();
    }
    throw Exception('Failed to load top rated TV shows');
  }

  Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    final url = Uri.parse(
      '$baseUrl/person/$personId?language=en-US'
      '&append_to_response=combined_credits',
    );

    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load person details: ${response.statusCode}');
  }

}
