import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_colors.dart';

/// Inline player for a case video, shared by the User and Doctor case detail
/// screens. Stays inside the page (no fullscreen route) so the doctor can keep
/// reading the answers while the clip plays.
class CaseVideoPlayer extends StatefulWidget {
  final String url;
  final String? label;
  const CaseVideoPlayer({super.key, required this.url, this.label});

  @override
  State<CaseVideoPlayer> createState() => _CaseVideoPlayerState();
}

class _CaseVideoPlayerState extends State<CaseVideoPlayer> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CaseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // A dead storage URL or a codec the device can't decode - show a retry
      // card rather than an empty black box.
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() {
      _controller?.dispose();
      _controller = null;
      _failed = false;
    });
    _load();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        // Replay from the top once the clip has run to the end.
        if (controller.value.position >= controller.value.duration) controller.seekTo(Duration.zero);
        controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    Widget body;
    if (_failed) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white60, size: 30),
            const SizedBox(height: 6),
            const Text('Video could not be loaded', style: TextStyle(color: Colors.white70, fontSize: 12)),
            TextButton(onPressed: _retry, child: const Text('Retry')),
          ],
        ),
      );
    } else if (controller == null || !controller.value.isInitialized) {
      body = const Center(
        child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70)),
      );
    } else {
      body = ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, child) => Stack(
          fit: StackFit.expand,
          children: [
            Center(child: AspectRatio(aspectRatio: value.aspectRatio, child: VideoPlayer(controller))),
            GestureDetector(
              onTap: _togglePlay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                color: value.isPlaying ? Colors.transparent : Colors.black26,
                child: Center(
                  child: value.isBuffering
                      ? const SizedBox(
                          width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70))
                      : AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: value.isPlaying ? 0 : 1,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 12, 2),
                    child: Row(
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _togglePlay,
                          icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(
                            '${_clock(value.position)} / ${_clock(value.duration)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(color: Colors.black87, child: AspectRatio(aspectRatio: 16 / 9, child: body)),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 6),
          Text(widget.label!, style: const TextStyle(color: AppColors.textLight, fontSize: 11.5)),
        ],
      ],
    );
  }
}

/// Renders every video attached to a case; nothing at all when there are none.
class CaseVideoList extends StatelessWidget {
  final List<String> urls;
  const CaseVideoList({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < urls.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == urls.length - 1 ? 0 : 12),
            child: CaseVideoPlayer(url: urls[i], label: urls.length > 1 ? 'Video ${i + 1} of ${urls.length}' : null),
          ),
      ],
    );
  }
}
