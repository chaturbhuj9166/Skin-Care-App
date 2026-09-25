import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../data/models/ticket_model.dart';
import '../../data/api/api_repository.dart';

Color ticketStatusColor(TicketStatus s) {
  switch (s) {
    case TicketStatus.open:
      return AppColors.statusAssigned;
    case TicketStatus.inProgress:
      return AppColors.accent;
    case TicketStatus.closed:
      return AppColors.secondary;
  }
}

Color ticketPriorityColor(TicketPriority p) {
  switch (p) {
    case TicketPriority.low:
      return AppColors.secondary;
    case TicketPriority.medium:
      return AppColors.accent;
    case TicketPriority.high:
      return AppColors.error;
  }
}

class TicketDetailScreen extends ConsumerWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    TicketModel? found;
    for (final t in repo.tickets) {
      if (t.id == ticketId) {
        found = t;
        break;
      }
    }
    if (found == null) {
      return const NotFoundScaffold(title: 'Ticket not found', message: 'This ticket is no longer available.');
    }
    final t = found;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Ticket')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(t.subject, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: t.status.label, color: ticketStatusColor(t.status)),
              _Pill(label: '${t.priority.label} priority', color: ticketPriorityColor(t.priority)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Raised on ${DateFormat('dd MMM yyyy, hh:mm a').format(t.createdAt)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Description', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Text(
              t.description.isEmpty ? 'No description provided.' : t.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: t.description.isEmpty ? AppColors.textMuted : AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Support reply', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (t.adminReply == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: AppColors.accent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Awaiting reply', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        SizedBox(height: 2),
                        Text('Our support team will get back to you here.',
                            style: TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text('Support team',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t.adminReply!, style: const TextStyle(fontSize: 13, height: 1.45)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
