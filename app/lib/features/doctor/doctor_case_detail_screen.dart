import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/case_video_player.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../core/widgets/photo_viewer.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';

class DoctorCaseDetailScreen extends ConsumerWidget {
  final String caseId;
  const DoctorCaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    CaseModel? found;
    for (final item in repo.cases) {
      if (item.id == caseId) {
        found = item;
        break;
      }
    }
    if (found == null) {
      return const NotFoundScaffold(title: 'Case not found', message: 'This case is no longer available.');
    }
    final c = found;
    final patient = c.patient;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(c.caseNumber),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: StatusChip(status: c.status)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                AppAvatar(
                  initials: (patient?.name.isNotEmpty ?? false) ? patient!.name.substring(0, 1) : '?',
                  seed: patient?.avatarSeed ?? 0,
                  size: 50,
                  imageUrl: patient?.avatarUrl,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient?.name ?? 'Unknown patient', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      const SizedBox(height: 3),
                      Text('${patient?.age ?? '-'} yrs • ${patient?.gender ?? '-'} • ${patient?.phone ?? '-'}', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Question Answers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...c.answers.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    expandedAlignment: Alignment.centerLeft,
                    title: Text(a.question, style: const TextStyle(color: AppColors.textLight, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(a.answer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      ),
                    ],
                  ),
                ),
              )),
          if (c.photoAssets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Photo Gallery', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: c.photoAssets
                  .map((p) => InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => showPhotoViewer(context, p),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            p,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.secondaryLight]),
                              ),
                              child: const Icon(Icons.broken_image_rounded, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (c.videoAssets.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Patient Video', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            CaseVideoList(urls: c.videoAssets),
          ],
          const SizedBox(height: 18),
          Text('Case Timeline', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _TimelineTile(icon: Icons.upload_file_rounded, label: 'Submitted', time: c.submittedAt, active: true),
          if (c.doctor != null) _TimelineTile(icon: Icons.person_add_rounded, label: 'Assigned to you', time: c.submittedAt.add(const Duration(minutes: 10)), active: true),
          if (c.solution != null) _TimelineTile(icon: Icons.check_circle_rounded, label: 'Solution provided', time: c.solution!.issuedAt, active: true, isLast: true),
          const SizedBox(height: 20),
          if (c.solution != null) ...[
            Text('Your Solution', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DIAGNOSIS', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(c.solution!.diagnosis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (c.solution!.prescription.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('PRESCRIPTION', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const SizedBox(height: 4),
                    ...c.solution!.prescription.map((p) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('• ${p.medicine} — ${p.instruction}${p.duration.isNotEmpty ? ' · ${p.duration}' : ''}', style: const TextStyle(fontSize: 12.5)),
                        )),
                  ],
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.push('/prescription/${c.id}'),
                    child: const Text('View full prescription'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (c.solution == null && c.status != CaseStatus.closed) ...[
            PrimaryButton(
              label: 'Write Solution',
              icon: Icons.edit_note_rounded,
              onPressed: () => context.push('/write-solution/${c.id}'),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Chat',
                  outlined: true,
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () => context.push('/doctor-chat/${c.id}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Schedule Call',
                  icon: Icons.videocam_rounded,
                  onPressed: () => _scheduleCallSheet(context, ref, c.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _scheduleCallSheet(BuildContext context, WidgetRef ref, String caseId) {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        String dateLabel(DateTime? d) => d == null ? 'Choose date' : DateFormat('EEE, dd MMM yyyy').format(d);
        String timeLabel(TimeOfDay? t) => t == null ? 'Choose time' : t.format(sheetContext);

        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Schedule Video Call', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: selectedDate ?? now.add(const Duration(days: 1)),
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 90)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 12),
                      Text(dateLabel(selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: sheetContext,
                    initialTime: selectedTime ?? const TimeOfDay(hour: 10, minute: 30),
                  );
                  if (picked != null) setSheetState(() => selectedTime = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 12),
                      Text(timeLabel(selectedTime), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: saving ? 'Scheduling…' : 'Confirm Schedule',
                icon: Icons.check_rounded,
                loading: saving,
                onPressed: (selectedDate == null || selectedTime == null || saving)
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        final at = DateTime(
                          selectedDate!.year,
                          selectedDate!.month,
                          selectedDate!.day,
                          selectedTime!.hour,
                          selectedTime!.minute,
                        );
                        final navigator = Navigator.of(sheetContext);
                        final messenger = ScaffoldMessenger.of(sheetContext);
                        try {
                          await ref.read(apiRepositoryProvider).scheduleCall(caseId, at);
                          navigator.pop();
                          messenger.showSnackBar(const SnackBar(content: Text('Call scheduled & patient notified')));
                        } catch (e) {
                          setSheetState(() => saving = false);
                          messenger.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
                        }
                      },
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime time;
  final bool active;
  final bool isLast;
  const _TimelineTile({required this.icon, required this.label, required this.time, this.active = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.border, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(DateFormat('dd MMM, hh:mm a').format(time), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
