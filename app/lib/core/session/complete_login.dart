import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';
import '../../data/api/auth_api.dart';
import 'session_controller.dart';

/// Shared tail of both login flows (patient OTP, doctor email/password).
///
/// Sets the token and loads the right data set BEFORE flipping `loggedIn`,
/// so the router's redirect (which fires the moment session state changes)
/// never lands on a home screen before currentUser/currentDoctor is ready.
/// Returns the route to open next.
Future<String> completeLogin(WidgetRef ref, LoginResult result) async {
  ApiClient.instance.setToken(result.token);
  final repo = ref.read(apiRepositoryProvider);
  try {
    if (result.isDoctor) {
      await repo.bootstrapDoctor();
    } else {
      await repo.bootstrapUser();
    }
  } catch (_) {
    ApiClient.instance.setToken(null);
    rethrow;
  }
  await ref.read(appSessionProvider.notifier).login(result.token, result.isDoctor ? AppRole.doctor : AppRole.user);
  if (result.isDoctor) return '/dashboard';
  return result.isNewUser ? '/complete-profile' : '/home';
}
