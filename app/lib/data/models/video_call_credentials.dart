/// Join credentials for an Agora RTC video call, returned by
/// GET /users/cases/:id/video-token (patient) or
/// GET /doctors/cases/:id/video-token (doctor).
class VideoCallCredentials {
  final String appId;
  final String channel;
  final String token;
  final int uid;

  const VideoCallCredentials({
    required this.appId,
    required this.channel,
    required this.token,
    required this.uid,
  });

  factory VideoCallCredentials.fromJson(Map<String, dynamic> json) {
    return VideoCallCredentials(
      appId: json['appId'] as String,
      channel: json['channel'] as String,
      token: json['token'] as String,
      // 0 means "let Agora assign a uid" - join with whatever comes back,
      // whether the backend sends it as a number or a numeric string.
      uid: json['uid'] is String ? int.parse(json['uid'] as String) : (json['uid'] as num).toInt(),
    );
  }
}
