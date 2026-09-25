import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'data/api/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never fatal: on Chrome/desktop there is no Firebase config, and the app
  // falls back to the server-generated dev OTP flow. See firebase_bootstrap.
  await initFirebase();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  }
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
      // Lets a foreground push show a SnackBar without a BuildContext.
      scaffoldMessengerKey: PushService.messengerKey,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
