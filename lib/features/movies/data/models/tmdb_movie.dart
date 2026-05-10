import '../../../../core/database/app_database.dart';

/// Wire-format movie from TMDB `/trending/movie/day` and `/movie/{id}` responses.
class TmdbMovie {
  const TmdbMovie({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.releaseDate,
  });

  final int id;
  final String title;
  final String? overview;

  /// Relative path like "/abc123.jpg". Combine with
  /// `ApiEndpoints.tmdbImageW185` or `tmdbImageW500` at render time.
  final String? posterPath;

  /// ISO date string from TMDB ("2008-07-18"). Stored as text — TMDB
  /// sometimes returns empty strings rather than nulls, normalized here.
  final String? releaseDate;

  String? get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return releaseDate!.substring(0, 4);
  }

  factory TmdbMovie.fromJson(Map<String, dynamic> json) {
    final rawDate = json['release_date'] as String?;
    return TmdbMovie(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      releaseDate: (rawDate == null || rawDate.isEmpty) ? null : rawDate,
    );
  }
}

class TmdbMoviePage {
  const TmdbMoviePage({
    required this.movies,
    required this.page,
    required this.totalPages,
  });

  final List<TmdbMovie> movies;
  final int page;
  final int totalPages;

  factory TmdbMoviePage.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(TmdbMovie.fromJson)
        .toList();
    return TmdbMoviePage(
      movies: results,
      page: json['page'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}

/// Adapts a Drift-generated `Movie` (from the local cache) into the same
/// shape the rest of the UI uses for trending data. Lets pages backed by
/// the DB (Saved Movies, Matches) reuse `MovieCard`, `SaveButton`, etc.
extension MovieToTmdb on Movie {
  TmdbMovie toTmdb() => TmdbMovie(
        id: id,
        title: title,
        overview: overview,
        posterPath: posterPath,
        releaseDate: releaseDate,
      );
}
