import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';
import '../../data/api/api_repository.dart';

/// Shown on cold boot for both the User and Doctor experiences of this one
/// app. Once the session finishes loading, it bootstraps the right data set
/// (`bootstrapUser`/`bootstrapDoctor`) based on the role the server decided
/// at OTP verification and lands on that role's home screen.
class AppSplashScreen extends ConsumerStatefulWidget {
  const AppSplashScreen({super.key});

  @override
  ConsumerState<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends ConsumerState<AppSplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    while (ref.read(appSessionProvider).loading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final elapsed = DateTime.now().difference(start);
    final remaining = const Duration(milliseconds: 2200) - elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;
    final session = ref.read(appSessionProvider);
    if (session.loggedIn) {
      try {
        final repo = ref.read(apiRepositoryProvider);
        if (session.role == AppRole.doctor) {
          await repo.bootstrapDoctor();
          if (!mounted) return;
          context.go('/dashboard');
        } else {
          await repo.bootstrapUser();
          if (!mounted) return;
          context.go('/home');
        }
      } catch (_) {
        await ref.read(appSessionProvider.notifier).logout();
        if (!mounted) return;
        context.go('/login');
      }
    } else if (session.onboardingSeen) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.splashGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Image.asset('assets/images/logo_icon_transparent.png', fit: BoxFit.contain),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack, begin: const Offset(0.4, 0.4))
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              const Text(
                'SkinCare',
                style: TextStyle(color: AppColors.primaryDark, fontSize: 30, fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              const SizedBox(height: 10),
              const Text(
                'Healthy Skin\nHappier You',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 15, height: 1.35),
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              const SizedBox(height: 60),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 7,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 5),
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.3), shape: BoxShape.circle)),
                ],
              ).animate().fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}
