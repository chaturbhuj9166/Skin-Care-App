import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/navigation/root_navigator.dart';
import '../../core/session/session_controller.dart';
import 'api_client.dart';

/// Runs when a push arrives while the app is killed or backgrounded. FCM draws
/// the system notification itself; this isolate only has to boot Firebase so
/// data-only messages don't fail.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Routes a tapped push straight to the screen it's about, for the case
/// where the app was backgrounded or fully killed when it arrived (a
/// foreground push is handled separately - see [PushService._handleForeground]
/// and the CALL_STARTED dialog wired in main.dart). Reads the persisted role
/// from secure storage rather than [PushService._basePath], since that's only
/// set once [PushService.start] has run, which hasn't necessarily happened
/// yet this launch if the app was killed and reopened via the tap itself.
Future<void> handleNotificationTap(RemoteMessage message) async {
  final data = message.data;
  final type = data['type'];
  final caseId = data['caseId'];
  if (caseId == null || caseId.isEmpty) return;
  final isDoctor = await readIsDoctorRolePersisted();
  // Freshly read right after the only await above, not a widget's own
  // context - there's no State/mounted to guard with here, and the router's
  // navigator key is stable for the app's lifetime.
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  switch (type) {
    case 'CALL_STARTED':
      // ignore: use_build_context_synchronously
      context.push(isDoctor ? '/doctor-video-call/$caseId' : '/video-call/$caseId');
    case 'NEW_MESSAGE':
      // ignore: use_build_context_synchronously
      context.push(isDoctor ? '/doctor-chat/$caseId' : '/chat/$caseId');
  }
}

/// FCM device-token registration and foreground message handling.
///
/// The token is per install, not per account, so it is registered against
/// whichever role just logged in ([start]) and deleted again on logout
/// ([stop]) - otherwise a doctor would keep getting a patient's pushes on a
/// shared device.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  /// Lets a push that arrives in the foreground surface a SnackBar without a
  /// BuildContext (and without pulling in a notifications plugin).
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  String? _token;
  String? _basePath;
  Future<void> Function()? _onForeground;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _messageSub;

  Future<void> start({
    required bool isDoctor,
    required Future<void> Function() onForegroundMessage,
  }) async {
    if (!firebaseReady) return;
    _basePath = isDoctor ? '/doctors' : '/users';
    _onForeground = onForegroundMessage;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      _refreshSub ??= messaging.onTokenRefresh.listen(_register);
      _messageSub ??= FirebaseMessaging.onMessage.listen(_handleForeground);
    } catch (e) {
      debugPrint('Push setup failed: $e');
    }
  }

  /// Must run while the JWT is still set, so the backend can find the row.
  Future<void> stop() async {
    final token = _token;
    final base = _basePath;
    _token = null;
    _onForeground = null;
    await _refreshSub?.cancel();
    await _messageSub?.cancel();
    _refreshSub = null;
    _messageSub = null;
    if (token == null || base == null) return;
    try {
      await ApiClient.instance.dio.delete('$base/device-token', data: {'token': token});
    } catch (e) {
      debugPrint('Device token delete failed: $e');
    }
  }

  Future<void> _register(String token) async {
    final base = _basePath;
    if (base == null) return;
    try {
      await ApiClient.instance.dio.post('$base/device-token', data: {'token': token});
      _token = token;
    } catch (e) {
      debugPrint('Device token registration failed: $e');
    }
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    try {
      await _onForeground?.call();
    } catch (e) {
      debugPrint('Refresh after push failed: $e');
    }
    final notification = message.notification;
    final text = notification?.body ?? notification?.title;
    if (text == null || text.isEmpty) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
