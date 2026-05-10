abstract final class ApiEndpoints {
  // Reqres — users API. Now requires an `x-api-key` header.
  static const reqresBaseUrl = 'https://reqres.in/api/';

  // TMDB — movies API (primary).
  static const tmdbBaseUrl = 'https://api.themoviedb.org/3/';
  static const tmdbImageBase = 'https://image.tmdb.org/t/p/';
  static const tmdbImageW185 = '${tmdbImageBase}w185';
  static const tmdbImageW500 = '${tmdbImageBase}w500';

  // OMDB — backup if TMDB is unavailable.
  static const omdbBaseUrl = 'https://www.omdbapi.com/';
}
