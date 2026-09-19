import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/api/api_repository.dart';

class DoctorAppointmentsScreen extends ConsumerStatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  ConsumerState<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends ConsumerState<DoctorAppointmentsScreen> {
  late DateTime _selectedDay;
  final _days = List.generate(7, (i) => DateTime.now().add(Duration(days: i - 1)));

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    final todays = repo.appointments.where((a) => _sameDay(a.scheduledAt, _selectedDay)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Appointments', style: Theme.of(context).textTheme.headlineSmall),
          ),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _days.length,
              separatorBuilder: (context, i) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = _days[i];
                final selected = _sameDay(d, _selectedDay);
                final isToday = _sameDay(d, DateTime.now());
                return InkWell(
                  onTap: () => setState(() => _selectedDay = d),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 54,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: isToday && !selected ? Border.all(color: AppColors.primary) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('E').format(d), style: TextStyle(fontSize: 11, color: selected ? Colors.white70 : AppColors.textLight)),
                        const SizedBox(height: 4),
                        Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textDark)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: todays.isEmpty
                ? const EmptyState(icon: Icons.event_busy_rounded, title: 'No appointments', subtitle: 'Nothing scheduled for this day.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: todays.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final a = todays[i];
                      final isPast = a.scheduledAt.isBefore(DateTime.now());
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.card),
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
                                  Text(DateFormat('hh:mm a').format(a.scheduledAt), style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                                ],
                              ),
                            ),
                            if (isPast)
                              const Text('Completed', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))
                            else
                              ElevatedButton(
                                onPressed: () => a.isVideo ? context.push('/doctor-video-call/${a.caseId}') : context.push('/doctor-chat/${a.caseId}'),
                                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
                                child: const Text('Join', style: TextStyle(fontSize: 12.5)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
