import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_api.dart';

/// A phone-auth problem with a message that is safe to show the user.
class PhoneAuthFailure implements Exception {
  final String message;
  const PhoneAuthFailure(this.message);
  @override
  String toString() => message;
}

/// Message for anything a login screen can catch - a Firebase phone-auth
/// failure or a failed call to our own backend.
String authErrorMessage(Object error) =>
    error is PhoneAuthFailure ? error.message : apiErrorMessage(error);

/// Real SMS verification through Firebase Phone Auth.
///
/// Android can finish the sign-in by itself (SMS auto-retrieval / instant
/// verification) at any moment after the code is requested - sometimes before
/// `codeSent`, more often while the OTP screen is already open. So a completed
/// sign-in is both latched in [takeAutoIdToken] and published on
/// [autoVerified], and whichever screen is mounted picks it up.
class PhoneAuthService {
  PhoneAuthService._();
  static final PhoneAuthService instance = PhoneAuthService._();

  final _autoVerified = StreamController<String>.broadcast();
  final _failures = StreamController<String>.broadcast();

  String? _autoIdToken;

  /// Firebase ID tokens from an auto-retrieved SMS code.
  Stream<String> get autoVerified => _autoVerified.stream;

  /// Failures that arrive after the code was sent (late auto-retrieval errors,
  /// a failed resend) and so can no longer be thrown from [sendCode].
  Stream<String> get failures => _failures.stream;

  String? takeAutoIdToken() {
    final token = _autoIdToken;
    _autoIdToken = null;
    return token;
  }

  /// Asks Firebase to SMS a code to [phone] (E.164, e.g. +919876543210).
  ///
  /// Resolves once the code is on its way - or, if Android verified the number
  /// instantly, with an [OtpRequest] carrying the ID token instead.
  Future<OtpRequest> sendCode(String phone, {int? resendToken}) {
    final completer = Completer<OtpRequest>();

    FirebaseAuth.instance
        .verifyPhoneNumber(
          phoneNumber: phone,
          forceResendingToken: resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            try {
              final idToken = await _signIn(credential);
              _autoIdToken = idToken;
              _autoVerified.add(idToken);
              if (!completer.isCompleted) {
                completer.complete(OtpRequest(phone: phone, autoIdToken: idToken));
              }
            } catch (e) {
              _failures.add(authErrorMessage(e));
            }
          },
          verificationFailed: (e) {
            final message = _message(e);
            if (completer.isCompleted) {
              _failures.add(message);
            } else {
              completer.completeError(PhoneAuthFailure(message));
            }
          },
          codeSent: (verificationId, forceResendingToken) {
            if (!completer.isCompleted) {
              completer.complete(OtpRequest(
                phone: phone,
                verificationId: verificationId,
                resendToken: forceResendingToken,
              ));
            }
          },
          // Auto-retrieval gave up; the user types the code by hand, which the
          // OTP screen already expects - nothing to do here.
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError((Object e) {
          if (!completer.isCompleted) {
            completer.completeError(PhoneAuthFailure(_message(e)));
          }
        });

    return completer.future;
  }

  /// Verifies a hand-typed code and returns the Firebase ID token to trade
  /// with our backend at POST /auth/firebase.
  Future<String> verifyCode(String verificationId, String smsCode) {
    return _signIn(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode));
  }

  Future<String> _signIn(PhoneAuthCredential credential) async {
    try {
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw const PhoneAuthFailure('Could not verify your number. Please try again.');
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthFailure(_message(e));
    }
  }

  /// Drops the Firebase session so the next login starts clean. Best effort.
  Future<void> signOut() async {
    _autoIdToken = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase sign-out failed: $e');
    }
  }

  String _message(Object error) {
    if (error is! FirebaseAuthException) return 'Could not verify your number. Please try again.';
    switch (error.code) {
      case 'invalid-phone-number':
        return 'That mobile number looks invalid. Check it and try again.';
      case 'invalid-verification-code':
        return 'That code is not right. Check the SMS and try again.';
      case 'session-expired':
      case 'invalid-verification-id':
        return 'That code has expired. Tap Resend to get a new one.';
      case 'too-many-requests':
      case 'quota-exceeded':
        return 'Too many attempts. Please try again in a little while.';
      case 'network-request-failed':
        return 'Could not reach the network. Check your connection and try again.';
      default:
        return error.message ?? 'Could not verify your number. Please try again.';
    }
  }
}
