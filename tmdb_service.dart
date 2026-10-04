import 'dart:convert';
import 'package:http/http.dart' as http;
import 'media.dart';

class TmdbService {
  static const String baseUrl = 'https://api.themoviedb.org/3';

  final String accessToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI1N2Y2ZjQzYjc3OWE3N2JmMDU5NWYyM2QxZjkzMWU0MyIsIm5iZiI6MTc5MTE0MDcwNy4zMTIsInN1YiI6IjZhYzJhMzYzZGY3ZDdhZmUyYjJhNWRkMiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.Qyxl0GhOjesmW0kRLmVFeBMO6Y-iMOnaPn3IOHDc7IM';


  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    
    final url = Uri.parse('$baseUrl/movie/$movieId?language=en-US' '&append_to_response=credits', );
    
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

    throw Exception(
      'Failed to load movie details: ${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> getTvDetails(int tvId) async {
    
    final url = Uri.parse('$baseUrl/tv/$tvId?language=en-US' '&append_to_response=credits', );
    
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

    throw Exception(
      'Failed to load TV show details: ${response.statusCode}',
    );
  }


Future<List<Media>> searchMoviesAndTvShows(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final movieResults = await _searchMovies(query);
    final tvResults = await _searchTvShows(query);

    return [
      ...movieResults,
      ...tvResults,
    ];
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
      throw Exception(
        'Movie search failed: ${response.statusCode}',
      );
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
      throw Exception(
        'TV show search failed: ${response.statusCode}',
      );
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



}