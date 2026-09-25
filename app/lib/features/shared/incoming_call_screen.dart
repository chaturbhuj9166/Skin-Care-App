import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/root_navigator.dart';
import '../../core/widgets/app_avatar.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/call_alert.dart';
import '../../data/models/case_model.dart';

/// Full-screen "someone is calling" takeover for a CALL_STARTED alert that
/// arrives while the app is in the foreground - pushed over whatever screen
/// the user is on (see main.dart), replacing the old small AlertDialog.
/// Reuses the pulsing-ring look from video_call_screen.dart's _Connecting
/// widget, the established "someone is calling" visual language in this app.
class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallAlert call;
  final bool isDoctorMode;
  const IncomingCallScreen({super.key, required this.call, required this.isDoctorMode});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  static const _ringInterval = Duration(milliseconds: 1500);
  static const _timeout = Duration(seconds: 50);

  Timer? _ringTimer;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _ringTimer = Timer.periodic(_ringInterval, (_) {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    });
    _timeoutTimer = Timer(_timeout, _decline);
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _stopRinging() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _decline() {
    _stopRinging();
    ref.read(apiRepositoryProvider).dismissIncomingCall();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _accept() {
    _stopRinging();
    ref.read(apiRepositoryProvider).dismissIncomingCall();
    final route = widget.isDoctorMode ? '/doctor-video-call/${widget.call.caseId}' : '/video-call/${widget.call.caseId}';
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    rootNavigatorKey.currentContext?.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(apiRepositoryProvider);
    CaseModel? c;
    for (final item in repo.cases) {
      if (item.id == widget.call.caseId) {
        c = item;
        break;
      }
    }
    final isUser = !widget.isDoctorMode;
    final found = c;
    final peerName = found == null ? widget.call.title : (isUser ? (found.doctor?.name ?? 'Doctor') : (found.patient?.name ?? 'Patient'));
    final peerSubtitle = found == null ? widget.call.body : (isUser ? (found.doctor?.specialization ?? 'Dermatologist') : 'Case ${found.caseNumber}');
    final peerAvatarUrl = found == null ? null : (isUser ? found.doctor?.avatarUrl : found.patient?.avatarUrl);
    final peerInitial = peerName.isNotEmpty ? peerName.replaceFirst('Dr. ', '')[0] : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0A7C6E), Color(0xFF0B1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 36),
              const Text('Incoming video call', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
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
                      child: AppAvatar(initials: peerInitial, seed: peerName.hashCode, size: 110, imageUrl: peerAvatarUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(peerName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Poppins'), textAlign: TextAlign.center),
              if (peerSubtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(peerSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RingButton(icon: Icons.call_end_rounded, label: 'Decline', background: AppColors.error, onTap: _decline),
                    _RingButton(icon: Icons.videocam_rounded, label: 'Accept', background: AppColors.secondary, onTap: _accept),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final VoidCallback onTap;
  const _RingButton({required this.icon, required this.label, required this.background, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: background.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
