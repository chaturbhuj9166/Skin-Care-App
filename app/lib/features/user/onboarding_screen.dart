import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  void _finish(WidgetRef ref, BuildContext context) {
    ref.read(appSessionProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 20, 0),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _finish(ref, context),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expert care\nfor your skin',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.15),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 10),
                  const Text(
                    'Get personalized advice, connect with certified dermatologists and track your progress.',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5),
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: Image.asset(
                        'assets/images/hero_skincare.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.96, 0.96)),
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: InkWell(
                      onTap: () => _finish(ref, context),
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.8, 0.8)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
