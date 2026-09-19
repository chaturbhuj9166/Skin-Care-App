import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/api/api_repository.dart';

class QuickAction {
  final IconData icon;
  final String label;
  final String route;
  const QuickAction({required this.icon, required this.label, required this.route});
}

const _quickActions = [
  QuickAction(icon: Icons.document_scanner_rounded, label: 'Submit\nProblem', route: '/submit-problem'),
  QuickAction(icon: Icons.folder_copy_rounded, label: 'My Cases', route: '/cases'),
  QuickAction(icon: Icons.chat_bubble_rounded, label: 'Chat', route: '/cases'),
  QuickAction(icon: Icons.notifications_none_rounded, label: 'Notifications', route: '/notifications'),
];

const _recommended = [
  (title: 'Acne Care', subtitle: 'Expert solutions', icon: Icons.face_retouching_natural_rounded, color: AppColors.primary),
  (title: 'Dark Spots', subtitle: 'Treatment', icon: Icons.blur_on_rounded, color: AppColors.accent),
  (title: 'Daily Skin Care', subtitle: 'Routine', icon: Icons.wb_sunny_rounded, color: AppColors.secondary),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final user = repo.currentUser;
    final active = repo.activeCase;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi, ${user.name.split(' ').first} 👋', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const Text('How is your skin today?', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded, color: AppColors.textDark),
                    ),
                  ),
                  if (repo.unreadNotificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => context.push('/profile'),
                borderRadius: BorderRadius.circular(24),
                child: AppAvatar(initials: user.name[0], seed: user.avatarSeed, size: 44, imageUrl: user.avatarUrl),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => context.push('/cases'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.textMuted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Search your cases...', style: TextStyle(color: AppColors.textMuted, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (active != null) ...[
            _ActiveCaseCard(caseNumber: active.caseNumber, status: active.status, onTap: () => context.push('/cases/${active.id}')),
            const SizedBox(height: 18),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -10,
                    bottom: -10,
                    width: 150,
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, Colors.white, Colors.white],
                        stops: [0, 0.35, 1],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        'assets/images/hero_skincare.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 210),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Get clear, healthy skin with expert advice',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () => context.push('/submit-problem'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Text('Start Analysis', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 16)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _quickActions.map((a) {
              return _QuickActionButton(
                action: a,
                onTap: () {
                  if (a.label.startsWith('Chat') && active != null) {
                    context.push('/chat/${active.id}');
                  } else {
                    context.push(a.route);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recommended for You', style: Theme.of(context).textTheme.titleLarge),
              TextButton(onPressed: () => context.push('/submit-problem'), child: const Text('See all')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommended.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final r = _recommended[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/submit-problem'),
                  child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: r.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(r.icon, color: r.color, size: 20),
                      ),
                      const Spacer(),
                      Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(r.subtitle, style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCaseCard extends StatelessWidget {
  final String caseNumber;
  final dynamic status;
  final VoidCallback onTap;
  const _ActiveCaseCard({required this.caseNumber, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Case · $caseNumber', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  const Text('Tap to view progress', style: TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                ],
              ),
            ),
            StatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
              child: Icon(action.icon, color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(action.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
