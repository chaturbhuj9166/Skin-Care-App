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

const _steps = ['Submitted', 'Assigned', 'In Review', 'Solved', 'Closed'];

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> {
  bool _answersExpanded = true;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    CaseModel? found;
    for (final c in repo.cases) {
      if (c.id == widget.caseId) {
        found = c;
        break;
      }
    }
    if (found == null) {
      return const NotFoundScaffold(title: 'Case not found', message: 'This case is no longer available.');
    }
    final c = found;
    final step = c.status.step;

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
          SizedBox(
            height: 70,
            child: Row(
              children: List.generate(_steps.length, (i) {
                final active = i <= step;
                final isLast = i == _steps.length - 1;
                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 3,
                              color: i == 0 ? Colors.transparent : (active ? AppColors.primary : AppColors.border),
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.border,
                              shape: BoxShape.circle,
                            ),
                            child: active ? const Icon(Icons.check, color: Colors.white, size: 11) : null,
                          ),
                          Expanded(
                            child: Container(
                              height: 3,
                              color: isLast ? Colors.transparent : (i < step ? AppColors.primary : AppColors.border),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_steps[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.primary : AppColors.textMuted,
                          )),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (c.doctor != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  AppAvatar(initials: c.doctor!.initials, seed: c.doctor!.avatarSeed, size: 48, online: c.doctor!.isOnline, imageUrl: c.doctor!.avatarUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.doctor!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(c.doctor!.specialization, style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: AppColors.accent),
                  SizedBox(width: 10),
                  Expanded(child: Text('Waiting for a doctor to be assigned to your case.', style: TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Submitted on ${DateFormat('dd MMM yyyy, hh:mm a').format(c.submittedAt)}',
              style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _answersExpanded = !_answersExpanded),
            child: Row(
              children: [
                Expanded(child: Text('Your Answers', style: Theme.of(context).textTheme.titleLarge)),
                Icon(_answersExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              ],
            ),
          ),
          if (_answersExpanded) ...[
            const SizedBox(height: 8),
            ...c.answers.map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.question, style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                      const SizedBox(height: 3),
                      Text(a.answer, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                )),
          ],
          if (c.photoAssets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Photos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: c.photoAssets.length,
                separatorBuilder: (context, i) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final url = c.photoAssets[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showPhotoViewer(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 84,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.secondaryLight]),
                          ),
                          child: const Icon(Icons.broken_image_rounded, color: AppColors.primary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (c.videoAssets.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Your Videos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            CaseVideoList(urls: c.videoAssets),
          ],
          if (c.solution != null) ...[
            const SizedBox(height: 18),
            Text('Solution', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.solution!.diagnosis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...c.solution!.prescription.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${p.medicine} — ${p.instruction}', style: const TextStyle(fontSize: 12.5)),
                      )),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => context.push('/prescription/${c.id}'),
                    child: const Text('View Full Prescription →'),
                  ),
                ],
              ),
            ),
          ],
          if (c.solution != null) ...[
            const SizedBox(height: 18),
            Text('Your Feedback', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (c.rating != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < c.rating!.score ? Icons.star_rounded : Icons.star_border_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                    ),
                    if (c.rating!.comment != null && c.rating!.comment!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(c.rating!.comment!, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ],
                ),
              )
            else
              PrimaryButton(
                label: 'Rate this consultation',
                outlined: true,
                icon: Icons.star_rounded,
                onPressed: () => _rateSheet(context, ref, c.id),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Chat',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: c.doctor == null ? null : () => context.push('/chat/${c.id}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Video Call',
                  outlined: true,
                  icon: Icons.videocam_rounded,
                  // Shown even with nothing booked, so the option is visible
                  // rather than silently missing from the screen.
                  onPressed: c.scheduledCallAt == null ? null : () => context.push('/video-call/${c.id}'),
                ),
              ),
            ],
          ),
          if (c.scheduledCallAt == null) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded, size: 13, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text('No call scheduled yet', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _rateSheet(BuildContext context, WidgetRef ref, String caseId) {
    int score = 0;
    final commentController = TextEditingController();
    bool saving = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate this consultation', style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final filled = i < score;
                    return GestureDetector(
                      onTap: () => setSheetState(() => score = i + 1),
                      child: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.accent, size: 40),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Share your experience (optional)'),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Submit Rating',
                loading: saving,
                onPressed: score == 0
                    ? null
                    : () async {
                        setSheetState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await ref.read(apiRepositoryProvider).submitRating(caseId, score: score, comment: commentController.text);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        } catch (e) {
                          setSheetState(() {
                            saving = false;
                            error = apiErrorMessage(e);
                          });
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
