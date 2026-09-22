import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/session/session_controller.dart';

class _Slide {
  final String title;
  final String body;
  final String image;
  const _Slide({required this.title, required this.body, required this.image});
}

// Slider artwork comes from Skin-Care-Landinpage/ (resized, flattened on white).
const _slides = [
  _Slide(
    title: 'Submit your skin problem',
    body: 'Answer a few quick questions and add photos of your concern - it takes under 3 minutes.',
    image: 'assets/images/onboarding_1.jpg',
  ),
  _Slide(
    title: 'Expert doctors review it',
    body: 'A certified dermatologist studies your case and can chat or video call with you.',
    image: 'assets/images/onboarding_2.jpg',
  ),
  _Slide(
    title: 'Get your personal solution',
    body: 'Receive a clear treatment plan and prescription, and track your progress over time.',
    image: 'assets/images/onboarding_3.jpg',
  ),
];

/// Three-slide intro (spec: PageView, dot indicators, Skip, Next/Get Started).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(appSessionProvider.notifier).completeOnboarding();
    context.go('/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
              child: Row(
                children: [
                  SizedBox(width: 32, height: 32, child: Image.asset('assets/images/logo_icon_transparent.png')),
                  const SizedBox(width: 8),
                  const Text('SkinCare', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.primaryDark)),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(onPressed: _isLast ? null : _finish, child: const Text('Skip')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i], index: i),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 56,
                    width: _isLast ? 172 : 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.primaryGradient),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _next,
                        child: Center(
                          child: _isLast
                              ? const FittedBox(
                                  child: Row(
                                    children: [
                                      Text('Get Started', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                                    ],
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final int index;
  const _SlideView({required this.slide, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // The artwork already carries its own headline and feature chips,
          // so it is shown whole (contain), never cropped.
          Expanded(
            child: Center(child: Image.asset(slide.image, fit: BoxFit.contain))
                .animate()
                .fadeIn(duration: 350.ms)
                .scale(begin: const Offset(0.96, 0.96)),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(999)),
            child: Text('Step ${index + 1} of ${_slides.length}',
                style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ).animate().fadeIn(delay: 60.ms),
          const SizedBox(height: 10),
          Text(slide.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.2, fontSize: 22))
              .animate()
              .fadeIn(delay: 100.ms)
              .slideX(begin: 0.06, end: 0),
          const SizedBox(height: 10),
          Text(slide.body, style: const TextStyle(color: AppColors.textLight, fontSize: 14, height: 1.5)).animate().fadeIn(delay: 180.ms),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
