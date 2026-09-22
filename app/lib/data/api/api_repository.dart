import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'socket_service.dart';
import '../models/appointment_model.dart';
import '../models/case_model.dart';
import '../models/doctor_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/question_model.dart';
import '../models/rating_model.dart';
import '../models/solution_model.dart';
import '../models/ticket_model.dart';
import '../models/user_model.dart';

/// Real, backend-backed repository. Public shape (fields + method names)
/// intentionally mirrors the previous MockRepository so screens need only a
/// provider swap plus `await` on what are now real network calls.
class ApiRepository extends ChangeNotifier {
  final Dio _dio = ApiClient.instance.dio;

  late UserModel currentUser;
  late DoctorModel currentDoctor;
  // Flips true once bootstrapUser()/bootstrapDoctor() has populated the
  // fields above - the routers redirect through the splash screen until this
  // is true, so a page refresh (which restores whatever route was in the URL
  // hash, skipping the splash screen) never renders a screen that reads
  // currentUser/currentDoctor before they're ready.
  bool bootstrapped = false;
  final List<CaseModel> cases = [];
  final List<NotificationModel> notifications = [];
  final List<TicketModel> tickets = [];
  final List<AppointmentModel> appointments = [];
  final List<QuestionModel> questionFlow = [];

  bool doctorAvailable = true;
  bool _isDoctorMode = false;

  // ------- Derived getters (unchanged shape from MockRepository) -------
  CaseModel? get activeCase {
    final active = cases.where((c) => c.status != CaseStatus.solved && c.status != CaseStatus.closed);
    return active.isEmpty ? null : active.first;
  }

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;

  List<CaseModel> get doctorCases => cases; // /doctors/cases is already scoped server-side

  // ------- Bootstrap (called once after login, before the app shell renders) -------

  Future<Response> _fetchActiveFlow() async {
    try {
      return await _dio.get('/users/question-flow');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Response(requestOptions: e.requestOptions, data: {'questionFlow': null});
      }
      rethrow;
    }
  }

  Future<void> bootstrapUser() async {
    _isDoctorMode = false;
    final results = await Future.wait([
      _dio.get('/users/profile'),
      _fetchActiveFlow(),
      _dio.get('/users/cases', queryParameters: {'limit': 100}),
      _dio.get('/users/notifications'),
      _dio.get('/users/tickets'),
      _dio.get('/users/appointments'),
    ]);

    currentUser = UserModel.fromJson(results[0].data['user']);

    final flowJson = results[1].data['questionFlow'];
    questionFlow
      ..clear()
      ..addAll(flowJson != null
          ? ((flowJson['questions'] as List).map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)))
          : const <QuestionModel>[]);
    _activeFlowId = flowJson?['id'] as String?;

    cases
      ..clear()
      ..addAll(((results[2].data['data'] as List)).map((c) => CaseModel.fromJson(c as Map<String, dynamic>, questions: questionFlow)));

    notifications
      ..clear()
      ..addAll(((results[3].data['data'] as List)).map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)));

    tickets
      ..clear()
      ..addAll(((results[4].data['data'] as List)).map((t) => TicketModel.fromJson(t as Map<String, dynamic>)));

    appointments
      ..clear()
      ..addAll(((results[5].data['data'] as List)).map((a) => AppointmentModel.fromJson(a as Map<String, dynamic>, isDoctorView: false)));

    bootstrapped = true;
    _listenSocket();
    notifyListeners();
  }

  Future<void> bootstrapDoctor() async {
    _isDoctorMode = true;
    final results = await Future.wait([
      _dio.get('/doctors/profile'),
      _dio.get('/doctors/cases', queryParameters: {'limit': 100}),
      _dio.get('/doctors/appointments'),
    ]);

    final doctorJson = results[0].data['doctor'];
    currentDoctor = DoctorModel.fromJson(doctorJson as Map<String, dynamic>);
    doctorAvailable = currentDoctor.isAvailable;

    cases
      ..clear()
      ..addAll(((results[1].data['data'] as List)).map((c) => CaseModel.fromJson(c as Map<String, dynamic>)));

    appointments
      ..clear()
      ..addAll(((results[2].data['data'] as List)).map((a) => AppointmentModel.fromJson(a as Map<String, dynamic>, isDoctorView: true)));

    bootstrapped = true;
    _listenSocket();
    notifyListeners();
  }

  String? _activeFlowId;
  bool _socketBound = false;

  void _listenSocket() {
    if (_socketBound) return;
    _socketBound = true;
    // The socket payload has no persisted id/caseId, so re-read the saved rows
    // instead of inventing one (tapping an invented id 404s and can't navigate).
    SocketService.instance.on('notification', (_) {
      if (!_isDoctorMode) refreshNotifications();
    });
    SocketService.instance.on('case_assigned', (_) => refreshCases());
    SocketService.instance.on('solution_added', (_) => refreshCases());
    SocketService.instance.on('case_status_changed', (_) => refreshCases());
    SocketService.instance.on('call_scheduled', (_) {
      refreshAppointments();
      refreshCases();
    });
  }

  Future<void> refreshNotifications() async {
    final res = await _dio.get('/users/notifications');
    notifications
      ..clear()
      ..addAll(((res.data['data'] as List)).map((n) => NotificationModel.fromJson(n as Map<String, dynamic>)));
    notifyListeners();
  }

  Future<void> refreshAppointments() async {
    final res = await _dio.get(_isDoctorMode ? '/doctors/appointments' : '/users/appointments');
    appointments
      ..clear()
      ..addAll(((res.data['data'] as List))
          .map((a) => AppointmentModel.fromJson(a as Map<String, dynamic>, isDoctorView: _isDoctorMode)));
    notifyListeners();
  }

  Future<void> refreshCases() async {
    final path = _isDoctorMode ? '/doctors/cases' : '/users/cases';
    final res = await _dio.get(path, queryParameters: {'limit': 100});
    cases
      ..clear()
      ..addAll(((res.data['data'] as List)).map((c) => CaseModel.fromJson(c as Map<String, dynamic>, questions: questionFlow)));
    notifyListeners();
  }

  // ------- Mutations (mirror the REST endpoints) -------

  Future<CaseModel> submitCase({
    required Map<String, dynamic> answers,
  }) async {
    final res = await _dio.post('/users/cases', data: {
      'questionFlowId': _activeFlowId,
      'answers': answers,
    });
    final newCase = CaseModel.fromJson(res.data['case'] as Map<String, dynamic>, questions: questionFlow);
    cases.insert(0, newCase);
    notifyListeners();
    return newCase;
  }

  Future<List<MessageModel>> fetchMessages(String caseId) async {
    final base = _isDoctorMode ? '/doctors' : '/users';
    final res = await _dio.get('$base/cases/$caseId/messages');
    return ((res.data['data'] as List)).map((m) => MessageModel.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<MessageModel> sendMessage(String caseId, {String? text, String? fileUrl}) async {
    final base = _isDoctorMode ? '/doctors' : '/users';
    final res = await _dio.post('$base/cases/$caseId/messages', data: {
      if (text != null) 'text': text,
      if (fileUrl != null) 'fileUrl': fileUrl,
    });
    return MessageModel.fromJson(res.data['message'] as Map<String, dynamic>);
  }

  void joinCaseRoom(String caseId) => SocketService.instance.joinCase(caseId);

  Future<void> submitSolution({
    required String caseId,
    required SolutionModel solution,
  }) async {
    await _dio.post('/doctors/cases/$caseId/solution', data: solution.toRequestJson());
    await refreshCases();
  }

  Future<void> scheduleCall(String caseId, DateTime at) async {
    await _dio.post('/doctors/cases/$caseId/schedule-call', data: {'scheduledAt': at.toUtc().toIso8601String()});
    final idx = cases.indexWhere((c) => c.id == caseId);
    if (idx != -1) cases[idx].scheduledCallAt = at;
    await refreshAppointments();
  }

  Future<void> markNotificationRead(String id) async {
    await _dio.patch('/users/notifications/$id/read');
    final n = notifications.firstWhere((n) => n.id == id);
    n.isRead = true;
    notifyListeners();
  }

  Future<void> submitRating(String caseId, {required int score, String? comment}) async {
    final res = await _dio.post('/users/cases/$caseId/rating', data: {
      'score': score,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    final caseRecord = cases.firstWhere((c) => c.id == caseId);
    caseRecord.rating = RatingModel.fromJson(res.data['rating'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> addTicket(String subject, String description, TicketPriority priority) async {
    final res = await _dio.post('/users/tickets', data: {
      'subject': subject,
      'description': description,
      'priority': priority.backendValue,
    });
    tickets.insert(0, TicketModel.fromJson(res.data['ticket'] as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> toggleDoctorAvailability(bool value) async {
    await _dio.put('/doctors/availability', data: {'isAvailable': value});
    doctorAvailable = value;
    notifyListeners();
  }

  Future<void> updateProfile({String? name, String? email, String? gender, int? age, String? avatar}) async {
    final res = await _dio.put('/users/profile', data: {
      if (name != null) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (avatar != null) 'avatar': avatar,
    });
    currentUser = UserModel.fromJson(res.data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> updateDoctorProfile({String? name, String? specialization, int? experience, String? avatar}) async {
    final res = await _dio.put('/doctors/profile', data: {
      if (name != null) 'name': name,
      if (specialization != null) 'specialization': specialization,
      if (experience != null) 'experience': experience,
      if (avatar != null) 'avatar': avatar,
    });
    currentDoctor = DoctorModel.fromJson(res.data['doctor'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> changeDoctorPassword(String oldPassword, String newPassword) async {
    await _dio.put('/doctors/profile/password', data: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }

  /// Uploads an image to the backend's local file store (see
  /// backend/src/middleware/upload.js) and returns its public URL. Works
  /// uniformly on web and mobile since it reads bytes rather than a file path.
  Future<String> uploadFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    final res = await _dio.post('/upload', data: form);
    return res.data['url'] as String;
  }
}

final apiRepositoryProvider = ChangeNotifierProvider<ApiRepository>((ref) => ApiRepository());
