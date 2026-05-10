import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../data/repositories/users_repository.dart';

class AddUserPage extends ConsumerStatefulWidget {
  const AddUserPage({super.key});

  @override
  ConsumerState<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends ConsumerState<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tasteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tasteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final fullName = _nameController.text.trim();
      // Reqres POSTs a single `name` field, but our local schema splits
      // first/last so the Users page can show them like the API users.
      final parts = fullName.split(RegExp(r'\s+'));
      final firstName = parts.first;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      final taste = _tasteController.text.trim();

      await ref.read(usersRepositoryProvider).createUser(
            firstName: firstName,
            lastName: lastName,
            movieTaste: taste.isEmpty ? null : taste,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $fullName')),
      );
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save user: $e')),
      );
    } finally {
      // Always reset _isSubmitting — even on success, in case pop didn't
      // happen (canPop was false). The indeterminate CircularProgressIndicator
      // would otherwise keep animating forever.
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add user')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            TextFormField(
              key: const Key('add_user_name_field'),
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Alex Doe',
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Please enter a name';
                if (v.length < 2) return 'Name is too short';
                return null;
              },
            ),
            const Gap(AppSpacing.md),
            TextFormField(
              key: const Key('add_user_taste_field'),
              controller: _tasteController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Movie taste',
                hintText: 'loves horror, no sad endings',
                helperText:
                    'Optional. Stored as the "job" field in Reqres.',
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const Gap(AppSpacing.lg),
            FilledButton(
              key: const Key('add_user_submit_button'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save user'),
            ),
          ],
        ),
      ),
    );
  }
}
