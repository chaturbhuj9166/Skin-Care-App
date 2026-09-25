import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';
import '../../data/models/case_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/video_call_credentials.dart';

/// The phases a call moves through, in order: [connecting] covers requesting
/// permissions, fetching the Agora token and joining the channel, right up
/// until the other side actually arrives; then [active] while they're in the
/// call; [remoteLeft] if they hang up first. [permissionDenied] and [error]
/// are dead ends reached instead of [connecting] - there's no engine to join
/// with, so they get their own screen rather than the call chrome.
enum _Phase { connecting, active, remoteLeft, permissionDenied, error }

/// Real Agora video call. Requests camera/mic permission, fetches a
/// short-lived RTC token for this case from the backend, joins the channel
/// and renders both feeds live. Used by both the User and Doctor routes -
/// [currentRole] only changes whose name/avatar is "the peer".
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
  bool _frontCamera = true;
  bool _controlsVisible = true;
  Offset? _pipOffset;

  _Phase _phase = _Phase.connecting;
  String _errorMessage = '';
  bool _permissionPermanentlyDenied = false;

  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  VideoViewController? _localVideoController;
  VideoViewController? _remoteVideoController;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Fire-and-forget: dispose() can't be async, and this is a safety net for
    // exit paths (system back gesture, screen popped from elsewhere) that
    // don't go through _endCall - _leaveAndDispose() is a no-op if that
    // already ran.
    unawaited(_leaveAndDispose());
    super.dispose();
  }

  /// Permissions -> token -> engine -> join. Any failure along the way lands
  /// on a dead-end screen instead of leaving the call chrome half-working.
  Future<void> _start() async {
    final granted = await _ensureCallPermissions();
    if (!granted || !mounted) return;

    late final VideoCallCredentials creds;
    try {
      creds = await ref.read(apiRepositoryProvider).fetchVideoCallToken(widget.caseId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = apiErrorMessage(e);
      });
      return;
    }
    if (!mounted) return;

    try {
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(RtcEngineContext(appId: creds.appId));

      final handler = RtcEngineEventHandler(
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!mounted) return;
          _remoteVideoController?.dispose();
          _remoteVideoController = VideoViewController.remote(
            rtcEngine: engine,
            canvas: VideoCanvas(uid: remoteUid, renderMode: RenderModeType.renderModeHidden),
            connection: connection,
          );
          setState(() {
            _remoteUid = remoteUid;
            _phase = _Phase.active;
          });
          _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _seconds++);
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!mounted) return;
          _timer?.cancel();
          _timer = null;
          _remoteVideoController?.dispose();
          _remoteVideoController = null;
          setState(() {
            _remoteUid = null;
            _phase = _Phase.remoteLeft;
          });
        },
        onError: (err, msg) {
          if (!mounted || _phase == _Phase.active || _phase == _Phase.remoteLeft) return;
          setState(() {
            _phase = _Phase.error;
            _errorMessage = 'Could not connect the call. Please try again.';
          });
        },
      );
      engine.registerEventHandler(handler);
      _handler = handler;

      await engine.enableVideo();
      await engine.startPreview();
      _localVideoController = VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0));

      await engine.joinChannel(
        token: creds.token,
        channelId: creds.channel,
        uid: creds.uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Could not start the call. Please try again.';
      });
    }
  }

  /// Checks (then, if needed, requests) camera + mic. Returns false and moves
  /// to [_Phase.permissionDenied] when either is refused, distinguishing
  /// "permanently denied" (needs Settings) from an in-session "not now".
  Future<bool> _ensureCallPermissions() async {
    var camera = await Permission.camera.status;
    var mic = await Permission.microphone.status;
    if (!camera.isGranted || !mic.isGranted) {
      final results = await [Permission.camera, Permission.microphone].request();
      camera = results[Permission.camera] ?? camera;
      mic = results[Permission.microphone] ?? mic;
    }
    if (camera.isGranted && mic.isGranted) return true;
    if (!mounted) return false;
    setState(() {
      _phase = _Phase.permissionDenied;
      _permissionPermanentlyDenied = camera.isPermanentlyDenied || mic.isPermanentlyDenied;
    });
    return false;
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final duration = _phase == _Phase.active ? _durationLabel : null;
    await _leaveAndDispose();
    if (!mounted) return;
    context.pop();
    if (duration != null) messenger?.showSnackBar(SnackBar(content: Text('Call ended · $duration')));
  }

  /// Leaves the channel and releases the engine so a second call attempt
  /// doesn't inherit a leaked native session. Safe to call more than once.
  Future<void> _leaveAndDispose() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    final handler = _handler;
    _handler = null;
    _localVideoController?.dispose();
    _localVideoController = null;
    _remoteVideoController?.dispose();
    _remoteVideoController = null;
    try {
      if (handler != null) engine.unregisterEventHandler(handler);
      await engine.leaveChannel();
    } catch (_) {
      // Best-effort - the engine is about to be released regardless.
    }
    await engine.release();
  }

  Future<void> _toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_muted;
    await engine.muteLocalAudioStream(next);
    if (!mounted) return;
    setState(() => _muted = next);
  }

  Future<void> _toggleCamera() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_cameraOff;
    await engine.muteLocalVideoStream(next);
    if (!mounted) return;
    setState(() => _cameraOff = next);
  }

  /// Flips the physical camera. The local *preview* texture is what goes
  /// stale here - the remote side keeps seeing the new camera fine either
  /// way, since that's the encoded stream, not this widget's render target -
  /// so the fix is a fresh [VideoViewController], not just flipping the flag.
  Future<void> _flipCamera() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.switchCamera();
    if (!mounted) return;
    final stale = _localVideoController;
    setState(() {
      _frontCamera = !_frontCamera;
      _localVideoController = VideoViewController(rtcEngine: engine, canvas: const VideoCanvas(uid: 0));
    });
    await stale?.dispose();
  }

  Future<void> _toggleSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_speakerOn;
    await engine.setEnableSpeakerphone(next);
    if (!mounted) return;
    setState(() => _speakerOn = next);
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
    final peerInitial = peerName.isNotEmpty ? peerName.replaceFirst('Dr. ', '')[0] : '?';

    if (_phase == _Phase.permissionDenied) {
      return _CallMessageScreen(
        icon: Icons.videocam_off_rounded,
        title: 'Camera & microphone needed',
        message: 'Camera and microphone access is needed for video calls. '
            '${_permissionPermanentlyDenied ? 'Enable them for this app in Settings to continue.' : 'Please allow access to continue.'}',
        primaryLabel: _permissionPermanentlyDenied ? 'Open settings' : 'Allow access',
        onPrimary: _permissionPermanentlyDenied ? () => openAppSettings() : _start,
      );
    }
    if (_phase == _Phase.error) {
      return _CallMessageScreen(
        icon: Icons.error_outline_rounded,
        title: 'Call unavailable',
        message: _errorMessage,
        primaryLabel: 'Try again',
        onPrimary: _start,
      );
    }

    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    const pipSize = Size(104, 148);
    final defaultPip = Offset(size.width - pipSize.width - 16, size.height - pipSize.height - padding.bottom - 150);
    final pip = _pipOffset ?? defaultPip;
    final connected = _phase == _Phase.active;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: connected ? () => setState(() => _controlsVisible = !_controlsVisible) : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: connected
                    ? _peerFeed()
                    : _phase == _Phase.remoteLeft
                        ? _PeerLeft(key: const ValueKey('left'), name: peerName, initial: peerInitial, imageUrl: peerAvatarUrl)
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

            // Top bar: back, peer name, status/timer.
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
                                if (connected) ...[
                                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(_durationLabel,
                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                                  Text('  ·  $peerSubtitle', style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                                ] else if (_phase == _Phase.remoteLeft)
                                  Text('$peerName left the call', style: const TextStyle(color: Colors.white70, fontSize: 12.5))
                                else
                                  Text(peerSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Self preview (picture-in-picture), draggable.
            if (connected)
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
                        Positioned.fill(child: _selfFeed()),
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
                          onTap: _engine == null ? null : _toggleMute,
                        ),
                        _CallButton(
                          icon: _cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          label: _cameraOff ? 'Camera on' : 'Camera',
                          active: _cameraOff,
                          onTap: _engine == null ? null : _toggleCamera,
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
                          onTap: (_engine == null || _cameraOff) ? null : _flipCamera,
                        ),
                        _CallButton(
                          icon: _speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                          label: _speakerOn ? 'Speaker' : 'Earpiece',
                          active: !_speakerOn,
                          onTap: _engine == null ? null : _toggleSpeaker,
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

  Widget _peerFeed() {
    final engine = _engine;
    final uid = _remoteUid;
    final controller = _remoteVideoController;
    if (engine == null || uid == null || controller == null) {
      return const SizedBox.expand(key: ValueKey('peer-empty'));
    }
    return SizedBox.expand(
      key: const ValueKey('peer'),
      child: AgoraVideoView(controller: controller),
    );
  }

  Widget _selfFeed() {
    if (_cameraOff) {
      return const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 28));
    }
    final controller = _localVideoController;
    if (controller == null) {
      return const Center(child: Icon(Icons.videocam_rounded, color: Colors.white38, size: 28));
    }
    // Flipping the camera plays a quick turn transition on the preview.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
      child: KeyedSubtree(key: ValueKey(_frontCamera), child: AgoraVideoView(controller: controller)),
    );
  }
}

/// "Calling..." state: the other person's avatar with pulsing rings. Shown
/// from the moment this screen opens (permission request, token fetch, join)
/// until the other side actually arrives.
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

/// Shown when the other participant hangs up first - a dead-end, static
/// version of [_Connecting] (no pulsing rings) so the screen doesn't look
/// like it's frozen mid-connect. The user still has to tap End to leave.
class _PeerLeft extends StatelessWidget {
  final String name;
  final String initial;
  final String? imageUrl;
  const _PeerLeft({super.key, required this.name, required this.initial, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0B1220),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 3)),
            child: AppAvatar(initials: initial, seed: name.hashCode, size: 110, imageUrl: imageUrl),
          ),
          const SizedBox(height: 18),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
          const SizedBox(height: 6),
          const Text('Left the call', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Full-screen dead end for permission-denied / token-or-join failures -
/// there's no engine to show the regular call chrome around.
class _CallMessageScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  const _CallMessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/splash'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
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
