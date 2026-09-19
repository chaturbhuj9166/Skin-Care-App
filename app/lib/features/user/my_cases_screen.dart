import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/case_model.dart';
import '../../data/api/api_repository.dart';

class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen> {
  int _tab = 0;
  final _tabs = const ['All', 'Active', 'Solved'];

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    var cases = List.of(repo.cases)..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    if (_tab == 1) {
      cases = cases.where((c) => c.status != CaseStatus.solved && c.status != CaseStatus.closed).toList();
    } else if (_tab == 2) {
      cases = cases.where((c) => c.status == CaseStatus.solved || c.status == CaseStatus.closed).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                if (context.canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                Text('My Cases', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final active = i == _tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(_tabs[i]),
                    selected: active,
                    onSelected: (_) => setState(() => _tab = i),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(color: active ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: cases.isEmpty
                ? const EmptyState(
                    icon: Icons.folder_off_rounded,
                    title: 'No cases yet',
                    subtitle: 'Submit your first skin concern to get expert advice.',
                  )
                : RefreshIndicator(
                    onRefresh: repo.refreshCases,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: cases.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = cases[i];
                        return InkWell(
                          onTap: () => context.push('/cases/${c.id}'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(c.caseNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const Spacer(),
                                    StatusChip(status: c.status),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(c.mainConcern, style: const TextStyle(color: AppColors.textDark, fontSize: 13)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(DateFormat('dd MMM yyyy').format(c.submittedAt),
                                        style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
                                    const Spacer(),
                                    if (c.doctor != null) ...[
                                      AppAvatar(initials: c.doctor!.initials, seed: c.doctor!.avatarSeed, size: 22, imageUrl: c.doctor!.avatarUrl),
                                      const SizedBox(width: 6),
                                      Text(c.doctor!.name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                    ] else
                                      const Text('Awaiting doctor', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                                  ],
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
