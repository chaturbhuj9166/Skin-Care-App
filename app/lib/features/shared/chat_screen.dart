import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/not_found_scaffold.dart';
import '../../data/api/api_client.dart';
import '../../data/api/api_repository.dart';
import '../../data/api/socket_service.dart';
import '../../data/models/case_model.dart';
import '../../data/models/message_model.dart';

/// Shared chat UI used by both the User app and the Doctor app.
/// [currentRole] decides which side of the conversation "you" are on.
/// Message history loads once via REST; new messages arrive live over the
/// same Socket.io case room the backend already broadcasts to.
class ChatScreen extends ConsumerStatefulWidget {
  final String caseId;
  final SenderType currentRole;
  const ChatScreen({super.key, required this.caseId, required this.currentRole});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _peerTyping = false;
  Timer? _stopTypingDebounce;

  void _onNewMessage(dynamic data) {
    final message = MessageModel.fromJson((data as Map).cast<String, dynamic>());
    if (_messages.any((m) => m.id == message.id)) return;
    // The message itself is proof typing stopped - don't wait for a separate
    // stop_typing event, which only fires after the sender's own 2s debounce.
    setState(() {
      _messages.add(message);
      _peerTyping = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onTyping(dynamic data) {
    final map = (data as Map).cast<String, dynamic>();
    final senderType = map['senderType'] == 'DOCTOR' ? SenderType.doctor : SenderType.user;
    if (senderType == widget.currentRole) return; // ignore our own echo
    setState(() => _peerTyping = true);
  }

  void _onStopTyping(dynamic _) => setState(() => _peerTyping = false);

  void _onMessagesRead(dynamic data) {
    final map = (data as Map).cast<String, dynamic>();
    final readBy = map['readBy'] == 'DOCTOR' ? SenderType.doctor : SenderType.user;
    if (readBy == widget.currentRole) return; // we're the one who just read - nothing of ours changed
    // The peer just opened the thread, so our own sent messages are now seen.
    setState(() {
      for (final m in _messages) {
        if (m.sender == widget.currentRole) m.isRead = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ref.read(apiRepositoryProvider).joinCaseRoom(widget.caseId);
    SocketService.instance.on('new_message', _onNewMessage);
    SocketService.instance.on('typing', _onTyping);
    SocketService.instance.on('stop_typing', _onStopTyping);
    SocketService.instance.on('messages_read', _onMessagesRead);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref.read(apiRepositoryProvider).fetchMessages(widget.caseId);
      if (!mounted) return;
      setState(() {
        _messages.addAll(history);
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  void dispose() {
    SocketService.instance.off('new_message', _onNewMessage);
    SocketService.instance.off('typing', _onTyping);
    SocketService.instance.off('stop_typing', _onStopTyping);
    SocketService.instance.off('messages_read', _onMessagesRead);
    _stopTypingDebounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    SocketService.instance.emit('typing', {'caseId': widget.caseId});
    _stopTypingDebounce?.cancel();
    _stopTypingDebounce = Timer(const Duration(seconds: 2), () {
      SocketService.instance.emit('stop_typing', {'caseId': widget.caseId});
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      final message = await ref.read(apiRepositoryProvider).sendMessage(widget.caseId, text: text);
      if (!mounted) return;
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() => _messages.add(message));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment() async {
    if (_sending) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final repo = ref.read(apiRepositoryProvider);
      final url = await repo.uploadFile(picked);
      final message = await repo.sendMessage(widget.caseId, fileUrl: url);
      if (!mounted) return;
      if (!_messages.any((m) => m.id == message.id)) {
        setState(() => _messages.add(message));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
      return const NotFoundScaffold(title: 'Chat unavailable', message: 'This conversation is no longer available.');
    }
    final peerName = widget.currentRole == SenderType.user ? (c.doctor?.name ?? 'Doctor') : (c.patient?.name ?? 'Patient');
    final peerOnline = widget.currentRole == SenderType.user ? (c.doctor?.isOnline ?? false) : true;
    final peerSeed = widget.currentRole == SenderType.user ? (c.doctor?.avatarSeed ?? 0) : (c.patient?.avatarSeed ?? 0);
    final peerAvatarUrl = widget.currentRole == SenderType.user ? c.doctor?.avatarUrl : c.patient?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            AppAvatar(initials: peerName.isNotEmpty ? peerName[0] : '?', seed: peerSeed, size: 38, online: peerOnline, imageUrl: peerAvatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(peerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(peerOnline ? 'Online' : 'Offline',
                      style: TextStyle(fontSize: 11, color: peerOnline ? AppColors.secondary : AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () => context.push('/video-call/${widget.caseId}')),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_peerTyping ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return const _TypingBubble();
                      }
                      final m = _messages[i];
                      final mine = m.sender == widget.currentRole;
                      return _MessageBubble(message: m, mine: mine);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, color: AppColors.textLight),
                    onPressed: _sending ? null : _sendAttachment,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                      child: TextField(
                        controller: _controller,
                        onChanged: _onTextChanged,
                        decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 19),
                    ),
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

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool mine;
  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 2),
            bottomRight: Radius.circular(mine ? 2 : 14),
          ),
          border: mine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(message.fileUrl!, width: 180, fit: BoxFit.cover),
              )
            else if (message.fileUrl != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file_rounded, size: 16, color: mine ? Colors.white : AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Attachment', style: TextStyle(color: mine ? Colors.white : AppColors.textDark, fontSize: 13)),
                ],
              )
            else
              Text(message.text, style: TextStyle(color: mine ? Colors.white : AppColors.textDark, fontSize: 13.5, height: 1.35)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('hh:mm a').format(message.time),
                    style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : AppColors.textMuted)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 13, color: message.isRead ? Colors.white : Colors.white54),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 150),
            SizedBox(width: 4),
            _Dot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = ((_c.value * 1000 - widget.delay) % 1000) / 1000;
        final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.scale(
          scale: scale.clamp(0.6, 1.0),
          child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle)),
        );
      },
    );
  }
}
