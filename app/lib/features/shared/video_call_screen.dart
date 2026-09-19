import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../data/models/case_model.dart';
import '../../data/models/message_model.dart';
import '../../data/api/api_repository.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String caseId;
  final SenderType currentRole;
  const VideoCallScreen({super.key, required this.caseId, required this.currentRole});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    CaseModel? c;
    for (final item in repo.cases) {
      if (item.id == widget.caseId) {
        c = item;
        break;
      }
    }
    if (c == null) {
      return const NotFoundScaffold(title: 'Call unavailable', message: 'This case is no longer available.');
    }
    final isUser = widget.currentRole == SenderType.user;
    final peerName = isUser ? (c.doctor?.name ?? 'Doctor') : (c.patient?.name ?? 'Patient');
    final peerAvatarUrl = isUser ? c.doctor?.avatarUrl : c.patient?.avatarUrl;
    final selfAvatarUrl = isUser ? repo.currentUser.avatarUrl : repo.currentDoctor.avatarUrl;
    final selfName = isUser ? repo.currentUser.name : repo.currentDoctor.name;
    final selfInitial = selfName.isNotEmpty ? selfName[0] : '?';

    // The other participant's live feed - falls back to a stock portrait when
    // no real avatar has been uploaded yet (no Agora feed is wired up here).
    final peerFeed = (peerAvatarUrl != null && peerAvatarUrl.isNotEmpty)
        ? Image.network(peerAvatarUrl, fit: BoxFit.cover)
        : Image.asset(
            isUser ? 'assets/images/doctor_hero.jpg' : 'assets/images/hero_skincare.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.5),
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        children: [
          Positioned.fill(child: peerFeed),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(peerName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                            Text(_durationLabel, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Positioned(
            top: 90,
            right: 16,
            child: Container(
              width: 92,
              height: 128,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF223148),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: _cameraOff
                  ? const Icon(Icons.videocam_off_rounded, color: Colors.white38)
                  : (selfAvatarUrl != null && selfAvatarUrl.isNotEmpty)
                      ? Image.network(selfAvatarUrl, fit: BoxFit.cover)
                      : Center(
                          child: AppAvatar(initials: selfInitial, seed: selfInitial.hashCode, size: 44),
                        ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallButton(
                    icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                    onTap: () => setState(() => _cameraOff = !_cameraOff),
                  ),
                  const SizedBox(width: 16),
                  _CallButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  const SizedBox(width: 16),
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    background: AppColors.error,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 16),
                  _CallButton(
                    icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    onTap: () => setState(() => _speakerOn = !_speakerOn),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  const _CallButton({required this.icon, required this.onTap, this.background});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(color: background ?? Colors.white24, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
