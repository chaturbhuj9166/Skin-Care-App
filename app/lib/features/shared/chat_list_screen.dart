import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/message_model.dart';

/// Bottom-nav "Chat" tab shared by both apps: every case with an assigned
/// doctor is a conversation - tapping one opens that case's ChatScreen.
class ChatListScreen extends ConsumerWidget {
  final SenderType currentRole;
  const ChatListScreen({super.key, required this.currentRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(apiRepositoryProvider);
    final isUser = currentRole == SenderType.user;
    final cases = (isUser ? repo.cases : repo.doctorCases).where((c) => isUser ? c.doctor != null : c.patient != null).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Chat'), automaticallyImplyLeading: false),
      body: cases.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              subtitle: 'Once a case is assigned to a doctor, you can chat here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: cases.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = cases[i];
                final peerName = isUser ? (c.doctor?.name ?? 'Doctor') : (c.patient?.name ?? 'Patient');
                final peerSeed = isUser ? (c.doctor?.avatarSeed ?? 0) : (c.patient?.avatarSeed ?? 0);
                final peerAvatarUrl = isUser ? c.doctor?.avatarUrl : c.patient?.avatarUrl;
                return InkWell(
                  onTap: () => context.push(isUser ? '/chat/${c.id}' : '/doctor-chat/${c.id}'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        AppAvatar(initials: peerName.isNotEmpty ? peerName[0] : '?', seed: peerSeed, size: 46, imageUrl: peerAvatarUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(peerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 3),
                              Text('${c.caseNumber} · ${DateFormat('dd MMM').format(c.submittedAt)}',
                                  style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
