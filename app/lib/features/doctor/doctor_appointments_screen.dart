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
  // Tile width + separator, used to scroll the strip to the selected day.
  static const _dayExtent = 64.0;

  late DateTime _selectedDay;
  late DateTime _visibleMonth;
  final _stripController = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollStripTo(_selectedDay.day));
  }

  @override
  void dispose() {
    _stripController.dispose();
    super.dispose();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  void _scrollStripTo(int day) {
    if (!_stripController.hasClients) return;
    final target = ((day - 1) * _dayExtent).clamp(0.0, _stripController.position.maxScrollExtent);
    _stripController.jumpTo(target);
  }

  void _shiftMonth(int delta) {
    setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollStripTo(_sameDay(_visibleMonth, _selectedDay) ? _selectedDay.day : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    final now = DateTime.now();
    final selectedDays = repo.appointments.where((a) => _sameDay(a.scheduledAt, _selectedDay)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final upcoming = repo.appointments.where((a) => a.scheduledAt.isAfter(now)).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final past = repo.appointments.where((a) => !a.scheduledAt.isAfter(now)).toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Appointments', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(DateFormat('MMMM yyyy').format(_visibleMonth),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous month',
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 78,
            child: ListView.separated(
              controller: _stripController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _daysInMonth(_visibleMonth),
              separatorBuilder: (context, i) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final d = DateTime(_visibleMonth.year, _visibleMonth.month, i + 1);
                final selected = _sameDay(d, _selectedDay);
                final isToday = _sameDay(d, now);
                final hasAppointment = repo.appointments.any((a) => _sameDay(a.scheduledAt, d));
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
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: hasAppointment ? (selected ? Colors.white : AppColors.accent) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: repo.appointments.isEmpty
                ? const EmptyState(icon: Icons.event_busy_rounded, title: 'No appointments', subtitle: 'Scheduled calls with your patients will show up here.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text(DateFormat('EEEE, d MMM').format(_selectedDay), style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      if (selectedDays.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('Nothing scheduled for this day.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                        )
                      else
                        ...selectedDays.map((a) => _AppointmentTile(appointment: a, showDate: false)),
                      const SizedBox(height: 20),
                      Text('Upcoming', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      if (upcoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('No upcoming calls.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                        )
                      else
                        ...upcoming.map((a) => _AppointmentTile(appointment: a, showDate: true)),
                      const SizedBox(height: 20),
                      Text('Past calls', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      if (past.isEmpty)
                        const Text('No past calls yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
                      else
                        ...past.map((a) => _AppointmentTile(appointment: a, showDate: true)),
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final dynamic appointment;
  final bool showDate;
  const _AppointmentTile({required this.appointment, required this.showDate});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final isPast = !a.scheduledAt.isAfter(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                Text(DateFormat(showDate ? 'MMM d, hh:mm a' : 'hh:mm a').format(a.scheduledAt),
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
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
  }
}
