import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_providers.dart';
import '../models/reqres_user.dart';

class UsersRemoteDataSource {
  UsersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ReqresUserPage> fetchUsers({required int page}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'users',
      queryParameters: {'page': page},
    );
    return ReqresUserPage.fromJson(response.data!);
  }

  /// POSTs a new user to Reqres. Reqres returns the assigned id as a string;
  /// we parse it to int because our local schema uses int for serverId.
  Future<int> createUser({
    required String name,
    required String job,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'users',
      data: {'name': name, 'job': job},
    );
    final raw = response.data!['id'];
    final asString = raw.toString();
    return int.parse(asString);
  }
}

final usersRemoteDataSourceProvider = Provider<UsersRemoteDataSource>((ref) {
  return UsersRemoteDataSource(ref.watch(reqresClientProvider));
});
