/// A "the other person just joined the video call" signal from the
/// 'notification' socket event (type CALL_STARTED). Surfaced by
/// [ApiRepository.incomingCall] since the repository has no BuildContext of
/// its own to show a dialog with.
class CallAlert {
  final String caseId;
  final String title;
  final String body;

  const CallAlert({required this.caseId, required this.title, required this.body});
}
