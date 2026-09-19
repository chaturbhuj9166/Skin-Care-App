import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_repository.dart';

class DoctorCasesScreen extends ConsumerStatefulWidget {
  const DoctorCasesScreen({super.key});

  @override
  ConsumerState<DoctorCasesScreen> createState() => _DoctorCasesScreenState();
}

class _DoctorCasesScreenState extends ConsumerState<DoctorCasesScreen> {
  int _tab = 0;
  String _query = '';
  final _tabs = const ['All', 'Pending', 'In Review', 'Solved'];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    var cases = repo.doctorCases;

    if (_tab == 1) cases = cases.where((c) => c.status == CaseStatus.pending || c.status == CaseStatus.assigned).toList();
    if (_tab == 2) cases = cases.where((c) => c.status == CaseStatus.inReview).toList();
    if (_tab == 3) cases = cases.where((c) => c.status == CaseStatus.solved || c.status == CaseStatus.closed).toList();
    if (_query.isNotEmpty) {
      cases = cases.where((c) => c.mainConcern.toLowerCase().contains(_query.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Text('My Cases', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search by concern...', border: InputBorder.none, prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final active = i == _tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_tabs[i]),
                    selected: active,
                    onSelected: (_) => setState(() => _tab = i),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(color: active ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: cases.isEmpty
                ? const EmptyState(icon: Icons.folder_off_rounded, title: 'No cases here', subtitle: 'New assigned cases will show up in this tab.')
                : RefreshIndicator(
                    onRefresh: repo.refreshCases,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: cases.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = cases[i];
                        final isNew = DateTime.now().difference(c.submittedAt).inHours < 6;
                        return InkWell(
                          onTap: () => context.push('/doctor-cases/${c.id}'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.card),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppAvatar(initials: c.mainConcern[0], seed: c.id.hashCode, size: 46),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                          if (isNew) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                                            ),
                                          ],
                                          const Spacer(),
                                          StatusChip(status: c.status),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('${c.mainConcern} concern', style: const TextStyle(fontSize: 12.5)),
                                      const SizedBox(height: 6),
                                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(c.submittedAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
