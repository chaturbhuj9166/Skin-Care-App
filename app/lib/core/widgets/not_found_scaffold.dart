import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'empty_state.dart';

/// Shown instead of crashing when a screen is opened for a case that isn't
/// (yet, or any longer) in the locally-loaded case list - e.g. a stale deep
/// link, a notification tap that raced bootstrap, or a case reassigned away
/// from this doctor.
class NotFoundScaffold extends StatelessWidget {
  final String title;
  final String message;
  const NotFoundScaffold({super.key, this.title = 'Not found', this.message = 'This case is no longer available.'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          // '/splash' re-derives the right home screen from the current
          // session's role, so this is safe for both User and Doctor.
          onPressed: () => context.canPop() ? context.pop() : context.go('/splash'),
        ),
        title: Text(title),
      ),
      body: EmptyState(
        icon: Icons.search_off_rounded,
        title: title,
        subtitle: message,
      ),
    );
  }
}
