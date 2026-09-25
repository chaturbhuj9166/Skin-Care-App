import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/notification_model.dart';
import '../../data/api/api_repository.dart';

IconData _iconFor(NotificationType t) {
  switch (t) {
    case NotificationType.caseUpdate:
      return Icons.assignment_turned_in_rounded;
    case NotificationType.message:
      return Icons.chat_bubble_rounded;
    case NotificationType.appointment:
      return Icons.videocam_rounded;
    case NotificationType.system:
      return Icons.notifications_rounded;
  }
}

/// Sends each notification to the screen that actually shows what it is about;
/// without a caseId the case-scoped routes can't be built, so fall back to the
/// nearest list screen instead of doing nothing.
void _openTarget(BuildContext context, NotificationModel n) {
  final caseId = n.caseId;
  switch (n.type) {
    case NotificationType.message:
      context.push(caseId != null ? '/chat/$caseId' : '/cases');
    case NotificationType.appointment:
      context.push('/appointments');
    case NotificationType.caseUpdate:
      context.push(caseId != null ? '/cases/$caseId' : '/cases');
    case NotificationType.system:
      if (caseId != null) context.push('/cases/$caseId');
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final items = repo.notifications;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Notifications')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_rounded,
              title: 'No notifications yet',
              subtitle: "We'll let you know when something new happens.",
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                return InkWell(
                  onTap: () {
                    repo.markNotificationRead(n.id);
                    _openTarget(context, n);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(_iconFor(n.type), color: AppColors.primary, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(height: 3),
                              Text(n.body, style: const TextStyle(color: AppColors.textLight, fontSize: 12, height: 1.35)),
                              const SizedBox(height: 6),
                              Text(DateFormat('dd MMM, hh:mm a').format(n.time), style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
