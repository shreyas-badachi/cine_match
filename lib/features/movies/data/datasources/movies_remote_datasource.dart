import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../models/tmdb_movie.dart';

class MoviesRemoteDataSource {
  MoviesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TmdbMoviePage> fetchTrending({required int page}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trending/movie/day',
      queryParameters: {
        'page': page,
        'language': 'en-US',
      },
    );
    return TmdbMoviePage.fromJson(response.data!);
  }

  Future<TmdbMovie> fetchDetail(int movieId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'movie/$movieId',
      queryParameters: {'language': 'en-US'},
    );
    return TmdbMovie.fromJson(response.data!);
  }
}

final moviesRemoteDataSourceProvider =
    Provider<MoviesRemoteDataSource>((ref) {
  return MoviesRemoteDataSource(ref.watch(tmdbClientProvider));
});
