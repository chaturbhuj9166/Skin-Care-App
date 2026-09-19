import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SkinCareApp()));
}

/// One app for both roles: the login screen only ever asks for a phone
/// number, and the server decides at OTP verification whether this is a
/// User or a Doctor session (see auth.controller.js's verifyOtp) - from
/// there [appRouterProvider] sends the session to the matching home screen.
class SkinCareApp extends ConsumerWidget {
  const SkinCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SkinCare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
