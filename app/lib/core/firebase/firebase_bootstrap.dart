import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

bool _ready = false;

/// True once Firebase started successfully on this device. Everything that
/// needs Firebase (real phone OTP, push) checks this first, because we also
/// run this same app on Chrome/desktop for testing, where no Firebase config
/// ships and `Firebase.initializeApp()` throws.
bool get firebaseReady => _ready;

/// Starts Firebase from the platform config file (android/app/google-services.json,
/// ios/Runner/GoogleService-Info.plist). Never throws: a missing or broken
/// config leaves [firebaseReady] false and the app falls back to the
/// server-generated dev OTP flow instead of failing to boot.
Future<void> initFirebase() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await Firebase.initializeApp();
    _ready = true;
  } catch (e) {
    debugPrint('Firebase unavailable, falling back to server OTP: $e');
  }
}
