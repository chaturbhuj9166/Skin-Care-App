import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/session/session_controller.dart';
import 'data/api/api_repository.dart';
import 'data/api/auth_api.dart';
import 'data/models/message_model.dart';
import 'features/doctor/doctor_appointments_screen.dart';
import 'features/doctor/doctor_case_detail_screen.dart';
import 'features/doctor/doctor_cases_screen.dart';
import 'features/doctor/doctor_shell.dart';
import 'features/doctor/write_solution_screen.dart';
import 'features/shared/chat_screen.dart';
import 'features/shared/video_call_screen.dart';
import 'features/user/appointments_screen.dart';
import 'features/user/case_detail_screen.dart';
import 'features/user/complete_profile_screen.dart';
import 'features/user/login_screen.dart';
import 'features/user/my_cases_screen.dart';
import 'features/user/notifications_screen.dart';
import 'features/user/onboarding_screen.dart';
import 'features/user/otp_screen.dart';
import 'features/user/prescription_screen.dart';
import 'features/user/splash_screen.dart';
import 'features/user/submit_problem_screen.dart';
import 'features/user/ticket_detail_screen.dart';
import 'features/user/tickets_screen.dart';
import 'features/user/user_shell.dart';

/// One router for one app: the login screen signs in either a patient
/// (phone + OTP) or a doctor (email + password), and every screen from both
/// roles lives in this same route tree from then on.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final session = ref.read(appSessionProvider);
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;

      // A page refresh (or a deep link) restores whatever route was in the
      // URL hash directly, bypassing the splash screen that normally waits
      // for the session to load and, if logged in, for the right bootstrap
      // call to populate currentUser/currentDoctor first. Detour through it
      // until both are done.
      final ready = !session.loading && (!session.loggedIn || ref.read(apiRepositoryProvider).bootstrapped);
      if (!ready) return '/splash';

      final onAuthFlow = loc == '/onboarding' || loc == '/login' || loc == '/verify-otp';
      if (!session.loggedIn && !onAuthFlow) return '/onboarding';
      // The OTP screen needs the pending request; a refresh/deep link loses it.
      if (loc == '/verify-otp' && state.extra is! OtpRequest) return '/login';
      if (session.loggedIn && onAuthFlow) return session.role == AppRole.doctor ? '/dashboard' : '/home';
      return null;
    },
    refreshListenable: _AppListenable(ref),
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const AppSplashScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => OtpScreen(request: state.extra as OtpRequest),
      ),

      // ---- User ----
      GoRoute(path: '/complete-profile', builder: (context, state) => const CompleteProfileScreen()),
      GoRoute(path: '/home', builder: (context, state) => const UserShell()),
      GoRoute(path: '/submit-problem', builder: (context, state) => const SubmitProblemScreen()),
      GoRoute(
        path: '/cases',
        builder: (context, state) => MyCasesScreen(autofocusSearch: state.uri.queryParameters['focus'] == 'search'),
      ),
      GoRoute(
        path: '/cases/:id',
        builder: (context, state) => CaseDetailScreen(caseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:caseId',
        builder: (context, state) => ChatScreen(caseId: state.pathParameters['caseId']!, currentRole: SenderType.user),
      ),
      GoRoute(
        path: '/video-call/:caseId',
        builder: (context, state) => VideoCallScreen(caseId: state.pathParameters['caseId']!, currentRole: SenderType.user),
      ),
      GoRoute(
        path: '/prescription/:caseId',
        builder: (context, state) => PrescriptionScreen(caseId: state.pathParameters['caseId']!),
      ),
      GoRoute(path: '/appointments', builder: (context, state) => const AppointmentsScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/tickets', builder: (context, state) => const TicketScreen()),
      GoRoute(
        path: '/tickets/:id',
        builder: (context, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (context, state) => const UserShell(initialIndex: 4)),

      // ---- Doctor ----
      GoRoute(path: '/dashboard', builder: (context, state) => const DoctorShell()),
      GoRoute(path: '/doctor-cases', builder: (context, state) => const DoctorCasesScreen()),
      GoRoute(
        path: '/doctor-cases/:id',
        builder: (context, state) => DoctorCaseDetailScreen(caseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/write-solution/:id',
        builder: (context, state) => WriteSolutionScreen(caseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/doctor-chat/:caseId',
        builder: (context, state) => ChatScreen(caseId: state.pathParameters['caseId']!, currentRole: SenderType.doctor),
      ),
      GoRoute(
        path: '/doctor-video-call/:caseId',
        builder: (context, state) => VideoCallScreen(caseId: state.pathParameters['caseId']!, currentRole: SenderType.doctor),
      ),
      GoRoute(path: '/doctor-appointments', builder: (context, state) => const DoctorAppointmentsScreen()),
    ],
  );
});

class _AppListenable extends ChangeNotifier {
  _AppListenable(Ref ref) {
    ref.listen(appSessionProvider, (prev, next) => notifyListeners());
    ref.listen(apiRepositoryProvider, (prev, next) => notifyListeners());
  }
}
