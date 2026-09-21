import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_repository.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final doctor = repo.currentDoctor;
    final cases = repo.doctorCases;
    final pending = cases.where((c) => c.status == CaseStatus.pending || c.status == CaseStatus.assigned).length;
    final solvedToday = cases.where((c) => c.status == CaseStatus.solved || c.status == CaseStatus.closed).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: AppColors.primaryGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Doctor Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                          const SizedBox(height: 3),
                          Text(doctor.specialization, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        AppAvatar(initials: doctor.initials, seed: doctor.avatarSeed, size: 46, online: repo.doctorAvailable, imageUrl: doctor.avatarUrl),
                        const SizedBox(height: 4),
                        Text(repo.doctorAvailable ? 'Online' : 'Offline',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.card),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Available for new cases', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Switch(
                        value: repo.doctorAvailable,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => repo.toggleDoctorAvailability(v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Assigned', value: '${cases.length}', color: AppColors.primary, icon: Icons.folder_copy_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Pending', value: '$pending', color: AppColors.accent, icon: Icons.hourglass_top_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Solved', value: '$solvedToday', color: AppColors.secondary, icon: Icons.check_circle_rounded)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Upcoming Appointments', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () => context.push('/doctor-appointments'), child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              if (repo.appointments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nothing scheduled yet', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ),
              ...repo.appointments.map((a) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.card),
                    child: Row(
                      children: [
                        AppAvatar(initials: a.patientOrDoctorName[0], seed: a.avatarSeed, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.patientOrDoctorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('${DateFormat('hh:mm a').format(a.scheduledAt)} • ${a.isVideo ? 'Video Call' : 'Chat'}',
                                  style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => a.isVideo ? context.push('/doctor-video-call/${a.caseId}') : context.push('/doctor-chat/${a.caseId}'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                          child: const Text('Join', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Cases', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () => context.push('/doctor-cases'), child: const Text('See all')),
                ],
              ),
              const SizedBox(height: 8),
              if (cases.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No cases assigned yet', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                ),
              ...cases.take(4).map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => context.push('/doctor-cases/${c.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AppAvatar(initials: c.mainConcern[0], seed: c.id.hashCode, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text('${c.mainConcern} Treatment', style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            StatusChip(status: c.status),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.card),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textLight, fontSize: 10.5)),
        ],
      ),
    );
  }
}
