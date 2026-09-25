import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/ticket_model.dart';
import '../../data/api/api_repository.dart';
import 'ticket_detail_screen.dart';

class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key});

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  void _openNewTicketSheet() {
    final subjectController = TextEditingController();
    final descController = TextEditingController();
    TicketPriority priority = TicketPriority.medium;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raise a Ticket', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                TextField(controller: subjectController, decoration: const InputDecoration(hintText: 'Subject')),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe the issue')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: TicketPriority.values
                      .map((p) => ChoiceChip(
                            label: Text(p.label),
                            selected: priority == p,
                            onSelected: (_) => setSheetState(() => priority = p),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(color: priority == p ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Submit Ticket',
                  onPressed: () {
                    if (subjectController.text.trim().isEmpty) return;
                    ref.read(apiRepositoryProvider).addTicket(subjectController.text.trim(), descController.text.trim(), priority);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    final tickets = repo.tickets;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Support Tickets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewTicketSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ticket'),
      ),
      body: RefreshIndicator(
        onRefresh: repo.refreshTickets,
        child: tickets.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(
                    child: EmptyState(icon: Icons.confirmation_num_rounded, title: 'No tickets raised', subtitle: 'Need help? Raise a support ticket.'),
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: tickets.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final t = tickets[i];
                return InkWell(
                  onTap: () => context.push('/tickets/${t.id}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(t.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: ticketPriorityColor(t.priority).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                            child: Text(t.priority.label, style: TextStyle(color: ticketPriorityColor(t.priority), fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(t.description, style: const TextStyle(color: AppColors.textLight, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(t.adminReply == null ? Icons.hourglass_empty_rounded : Icons.support_agent_rounded,
                              size: 14, color: t.adminReply == null ? AppColors.textMuted : AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.adminReply == null ? 'Awaiting reply' : 'Support replied · tap to read',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: t.adminReply == null ? AppColors.textMuted : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: ticketStatusColor(t.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                            child: Text(t.status.label, style: TextStyle(color: ticketStatusColor(t.status), fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                          const Spacer(),
                          Text(DateFormat('dd MMM yyyy').format(t.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
