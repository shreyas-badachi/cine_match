/// Wire-format user from Reqres `/api/users` responses.
class ReqresUser {
  const ReqresUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.avatar,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String avatar;

  factory ReqresUser.fromJson(Map<String, dynamic> json) {
    return ReqresUser(
      id: json['id'] as int,
      email: json['email'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      avatar: json['avatar'] as String,
    );
  }
}

class ReqresUserPage {
  const ReqresUserPage({
    required this.users,
    required this.page,
    required this.totalPages,
  });

  final List<ReqresUser> users;
  final int page;
  final int totalPages;

  factory ReqresUserPage.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReqresUser.fromJson)
        .toList();
    return ReqresUserPage(
      users: data,
      page: json['page'] as int,
      totalPages: json['total_pages'] as int,
    );
  }
}
