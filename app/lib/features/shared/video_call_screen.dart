import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../data/models/case_model.dart';
import '../../data/models/message_model.dart';
import '../../data/api/api_repository.dart';

/// DUMMY video call. There is no Agora App ID yet, so this screen simulates
/// the call: a short "connecting" phase, then the other person's photo as
/// their "video" and yours in a draggable picture-in-picture preview. Every
/// control (mute / camera / flip / speaker / end) works on local state.
///
/// When Agora is available: create the RtcEngine in initState, join the
/// channel with the case's roomId + a token from the backend, and replace
/// [_peerFeed] / [_selfFeed] with AgoraVideoView widgets - the layout and
/// controls stay as they are.
class VideoCallScreen extends ConsumerStatefulWidget {
  final String caseId;
  final SenderType currentRole;
  const VideoCallScreen({super.key, required this.caseId, required this.currentRole});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  Timer? _timer;
  Timer? _connectTimer;
  bool _connected = false;
  int _seconds = 0;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  bool _controlsVisible = true;
  Offset? _pipOffset;

  @override
  void initState() {
    super.initState();
    _connectTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() => _connected = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
    });
  }

  @override
  void dispose() {
    _connectTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endCall() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final duration = _connected ? _durationLabel : null;
    context.pop();
    if (duration != null) messenger?.showSnackBar(SnackBar(content: Text('Call ended · $duration')));
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
    final peerSubtitle = isUser ? (c.doctor?.specialization ?? 'Dermatologist') : 'Case ${c.caseNumber}';
    final peerAvatarUrl = isUser ? c.doctor?.avatarUrl : c.patient?.avatarUrl;
    final selfAvatarUrl = isUser ? repo.currentUser.avatarUrl : repo.currentDoctor.avatarUrl;
    final selfName = isUser ? repo.currentUser.name : repo.currentDoctor.name;
    final peerInitial = peerName.isNotEmpty ? peerName.replaceFirst('Dr. ', '')[0] : '?';
    final selfInitial = selfName.isNotEmpty ? selfName[0] : '?';

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    const pipSize = Size(104, 148);
    final defaultPip = Offset(size.width - pipSize.width - 16, size.height - pipSize.height - padding.bottom - 150);
    final pip = _pipOffset ?? defaultPip;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _connected ? () => setState(() => _controlsVisible = !_controlsVisible) : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: _connected
                    ? _peerFeed(isUser, peerAvatarUrl)
                    : _Connecting(key: const ValueKey('connecting'), name: peerName, initial: peerInitial, imageUrl: peerAvatarUrl),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.55), Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.25, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),

            // Top bar: back, peer name, status/timer, demo badge.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              top: _controlsVisible ? 0 : -120,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                        onPressed: _endCall,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(peerName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (_connected) ...[
                                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(_durationLabel,
                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                                  Text('  ·  $peerSubtitle', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                                ] else
                                  Text(peerSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_outlined, color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text('Demo call', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Self preview (picture-in-picture), draggable.
            if (_connected)
              Positioned(
                left: pip.dx,
                top: pip.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() {
                    final next = pip + d.delta;
                    _pipOffset = Offset(
                      next.dx.clamp(8, size.width - pipSize.width - 8),
                      next.dy.clamp(padding.top + 8, size.height - pipSize.height - padding.bottom - 8),
                    );
                  }),
                  child: Container(
                    width: pipSize.width,
                    height: pipSize.height,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFF223148),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: _selfFeed(selfAvatarUrl, selfInitial)),
                        if (_muted)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                              child: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
              ),

            // Controls.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              left: 0,
              right: 0,
              bottom: _controlsVisible ? 0 : -160,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallButton(
                          icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _muted ? 'Unmute' : 'Mute',
                          active: _muted,
                          onTap: () => setState(() => _muted = !_muted),
                        ),
                        _CallButton(
                          icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          label: _cameraOff ? 'Camera on' : 'Camera',
                          active: _cameraOff,
                          onTap: () => setState(() => _cameraOff = !_cameraOff),
                        ),
                        _CallButton(
                          icon: Icons.call_end_rounded,
                          label: 'End',
                          background: AppColors.error,
                          size: 64,
                          onTap: _endCall,
                        ),
                        _CallButton(
                          icon: Icons.flip_camera_ios_rounded,
                          label: 'Flip',
                          onTap: _cameraOff ? null : () => setState(() => _frontCamera = !_frontCamera),
                        ),
                        _CallButton(
                          icon: _speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                          label: _speakerOn ? 'Speaker' : 'Earpiece',
                          active: !_speakerOn,
                          onTap: () => setState(() => _speakerOn = !_speakerOn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peerFeed(bool isUser, String? peerAvatarUrl) {
    return SizedBox.expand(
      key: const ValueKey('peer'),
      child: (peerAvatarUrl != null && peerAvatarUrl.isNotEmpty)
          ? Image.network(peerAvatarUrl, fit: BoxFit.cover)
          : Image.asset(
              isUser ? 'assets/images/doctor_hero.jpg' : 'assets/images/hero_skincare.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.5),
            ),
    );
  }

  Widget _selfFeed(String? selfAvatarUrl, String selfInitial) {
    if (_cameraOff) {
      return const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 28));
    }
    final Widget feed = (selfAvatarUrl != null && selfAvatarUrl.isNotEmpty)
        ? Image.network(selfAvatarUrl, fit: BoxFit.cover)
        : Center(child: AppAvatar(initials: selfInitial, seed: selfInitial.hashCode, size: 48));
    // Flipping the (dummy) camera plays a quick turn transition on the preview.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: KeyedSubtree(key: ValueKey(_frontCamera), child: feed),
    );
  }
}

/// "Calling..." state: the other person's avatar with pulsing rings.
class _Connecting extends StatelessWidget {
  final String name;
  final String initial;
  final String? imageUrl;
  const _Connecting({super.key, required this.name, required this.initial, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0A7C6E), Color(0xFF0B1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2)),
                  )
                      .animate(onPlay: (c) => c.repeat(), delay: (i * 600).ms)
                      .scale(begin: const Offset(1, 1), end: const Offset(1.8, 1.8), duration: 1800.ms)
                      .fadeOut(duration: 1800.ms),
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  child: AppAvatar(initials: initial, seed: name.hashCode, size: 110, imageUrl: imageUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          const Text('Connecting…', style: TextStyle(color: Colors.white70, fontSize: 14))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 700.ms),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? background;
  final bool active;
  final double size;
  const _CallButton({required this.icon, required this.label, required this.onTap, this.background, this.active = false, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.16));
    final fg = background != null ? Colors.white : (active ? const Color(0xFF0B1220) : Colors.white);
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: background != null ? [BoxShadow(color: background!.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))] : null,
              ),
              child: Icon(icon, color: fg, size: size * 0.44),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
