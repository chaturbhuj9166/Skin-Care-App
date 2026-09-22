import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: SkinCareApp()));
}

/// One app (one APK) for both roles: patients log in with phone + OTP,
/// doctors with email + password, and [appRouterProvider] sends each
/// session to the matching home screen.
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
