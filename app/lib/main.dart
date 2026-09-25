import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/navigation/root_navigator.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_repository.dart';
import 'data/api/push_service.dart';
import 'data/models/call_alert.dart';
import 'features/shared/incoming_call_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never fatal: on Chrome/desktop there is no Firebase config, and the app
  // falls back to the server-generated dev OTP flow. See firebase_bootstrap.
  await initFirebase();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    // A tap while the app is backgrounded fires this listener directly; a tap
    // that cold-starts the app (it was fully killed) instead has to be picked
    // up from getInitialMessage() once, since onMessageOpenedApp never fires
    // for the launch that the tap itself caused.
    FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => handleNotificationTap(message));
    });
    // Android only: the app may instead have been cold-started by tapping the
    // high-priority "incoming call" notification pushBackgroundHandler drew
    // itself (see push_service.dart) - that one isn't an FCM notification, so
    // getInitialMessage() above never sees it.
    WidgetsBinding.instance.addPostFrameCallback((_) => handleLocalNotificationLaunch());
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
    // The other side of a scheduled call just joined it (socket event
    // 'notification', type CALL_STARTED) - show a full-screen incoming-call
    // takeover instead of relying on the recipient to notice a system push.
    ref.listen<ApiRepository>(apiRepositoryProvider, (previous, next) {
      final call = next.incomingCall;
      if (call == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        next.dismissIncomingCall();
        _showIncomingCallScreen(call, next.isDoctorMode);
      });
    });
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

void _showIncomingCallScreen(CallAlert call, bool isDoctorMode) {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  navigator.push(MaterialPageRoute<void>(
    builder: (_) => IncomingCallScreen(call: call, isDoctorMode: isDoctorMode),
    fullscreenDialog: true,
  ));
}
