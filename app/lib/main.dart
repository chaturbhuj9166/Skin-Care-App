import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';
import 'core/constants/app_colors.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/navigation/root_navigator.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_repository.dart';
import 'data/api/push_service.dart';
import 'data/models/call_alert.dart';

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
    // 'notification', type CALL_STARTED) - pop a Join/Dismiss dialog instead
    // of relying on the recipient to notice a system push on their own.
    ref.listen<ApiRepository>(apiRepositoryProvider, (previous, next) {
      final call = next.incomingCall;
      if (call == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        next.dismissIncomingCall();
        _showIncomingCallDialog(call, next.isDoctorMode);
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

void _showIncomingCallDialog(CallAlert call, bool isDoctorMode) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 32),
      title: Text(call.title),
      content: Text(call.body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Dismiss')),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            final route = isDoctorMode ? '/doctor-video-call/${call.caseId}' : '/video-call/${call.caseId}';
            rootNavigatorKey.currentContext?.push(route);
          },
          child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ],
    ),
  );
}
