enum Media{ 
    movie, 
    tvshow,
}

class MediaItem{
    final int id;
    final Media mediaType;
    final String title;
    final String genre;
    final String posterPath;
    final String actors;
    final String plot;
    final String rating;
    final String reviews;
    final String trailer;
    final String streamingPlatform;
    final List <String> cast;

    MediaItem({
        required this.id,
        required this.mediaType,
        required this.title,
        required this.genre,
        required this.posterPath,
        required this.actors,
        required this.plot,
        required this.rating,
        required this.reviews,
        required this.trailer,
        required this.streamingPlatform,
        required this.cast,
    });

String get posterUrl {
    if (posterPath.isEmpty) {
      return '';
    }

    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

}