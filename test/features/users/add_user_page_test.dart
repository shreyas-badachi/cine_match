import 'package:cine_match/core/database/daos/users_dao.dart';
import 'package:cine_match/features/users/data/models/reqres_user.dart';
import 'package:cine_match/features/users/data/repositories/users_repository.dart';
import 'package:cine_match/features/users/presentation/pages/add_user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUsersRepository implements UsersRepository {
  ({String firstName, String lastName, String? movieTaste})? lastCall;
  bool throwOnNext = false;

  @override
  Future<int> createUser({
    required String firstName,
    required String lastName,
    String? movieTaste,
  }) async {
    if (throwOnNext) {
      throwOnNext = false;
      throw Exception('boom');
    }
    lastCall = (
      firstName: firstName,
      lastName: lastName,
      movieTaste: movieTaste,
    );
    return 42;
  }

  @override
  Stream<List<UserWithSavedCount>> watchAll() => const Stream.empty();

  @override
  Future<ReqresUserPage> fetchPage(int page) async {
    throw UnimplementedError();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildPage(_FakeUsersRepository fake) {
  return ProviderScope(
    overrides: [
      usersRepositoryProvider.overrideWith((_) => fake),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const AddUserPage(),
    ),
  );
}

void main() {
  testWidgets('valid name + taste → repository.createUser called with split name', (tester) async {
    final fake = _FakeUsersRepository();

    await tester.pumpWidget(_buildPage(fake));
    await tester.enterText(find.byKey(const Key('add_user_name_field')), 'Alex Doe');
    await tester.enterText(
      find.byKey(const Key('add_user_taste_field')),
      'loves horror',
    );
    await tester.tap(find.byKey(const Key('add_user_submit_button')));
    await tester.pumpAndSettle();

    expect(fake.lastCall?.firstName, 'Alex');
    expect(fake.lastCall?.lastName, 'Doe');
    expect(fake.lastCall?.movieTaste, 'loves horror');
  });

  testWidgets('single-word name lands in firstName, lastName is empty string', (tester) async {
    final fake = _FakeUsersRepository();

    await tester.pumpWidget(_buildPage(fake));
    await tester.enterText(find.byKey(const Key('add_user_name_field')), 'Cher');
    await tester.tap(find.byKey(const Key('add_user_submit_button')));
    await tester.pumpAndSettle();

    expect(fake.lastCall?.firstName, 'Cher');
    expect(fake.lastCall?.lastName, '');
    expect(fake.lastCall?.movieTaste, isNull);
  });

  testWidgets('empty name shows validation error and does not call repository', (tester) async {
    final fake = _FakeUsersRepository();

    await tester.pumpWidget(_buildPage(fake));
    await tester.tap(find.byKey(const Key('add_user_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a name'), findsOneWidget);
    expect(fake.lastCall, isNull);
  });

  testWidgets('repository failure surfaces a snackbar and re-enables the button', (tester) async {
    final fake = _FakeUsersRepository()..throwOnNext = true;

    await tester.pumpWidget(_buildPage(fake));
    await tester.enterText(find.byKey(const Key('add_user_name_field')), 'Alex');
    await tester.tap(find.byKey(const Key('add_user_submit_button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not save user'),
      findsOneWidget,
    );
    // Button is back to "Save user" text (not the spinner).
    expect(find.text('Save user'), findsOneWidget);
  });
}
