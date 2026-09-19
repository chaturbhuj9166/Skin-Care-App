import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/api/api_repository.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final upcoming = repo.appointments.where((a) => a.scheduledAt.isAfter(DateTime.now())).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = repo.appointments.where((a) => !a.scheduledAt.isAfter(DateTime.now())).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: SafeArea(
        top: false,
        child: repo.appointments.isEmpty
            ? const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No appointments',
                subtitle: 'Scheduled video calls with your doctor will show up here.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (upcoming.isNotEmpty) ...[
                    Text('Upcoming', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ...upcoming.map((a) => _AppointmentTile(appointment: a, isPast: false)),
                    const SizedBox(height: 20),
                  ],
                  if (past.isNotEmpty) ...[
                    Text('Past', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    ...past.map((a) => _AppointmentTile(appointment: a, isPast: true)),
                  ],
                ],
              ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final dynamic appointment;
  final bool isPast;
  const _AppointmentTile({required this.appointment, required this.isPast});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          AppAvatar(initials: a.patientOrDoctorName[0], seed: a.avatarSeed, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.patientOrDoctorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  DateFormat('MMM d, hh:mm a').format(a.scheduledAt),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isPast)
            const Text('Completed', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))
          else
            ElevatedButton(
              onPressed: () => context.push('/video-call/${a.caseId}'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Text('Join', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
