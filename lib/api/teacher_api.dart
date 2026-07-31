import 'package:dio/dio.dart';
import '../models/models.dart';
import 'api_client.dart';

/// `IntellectCRM.Client/src/api/services/teacher.ts` bilan bir xil — barcha
/// `/teacher/*` endpointlar (backend `TeacherPortalController`).
class TeacherApi {
  TeacherApi._();

  /// Javob 2xx bo'lmasa xatoni serverdagi `message` bilan otadi.
  /// `ApiException` status kodini ham saqlaydi (log/diagnostika uchun).
  static void _check(Response res) {
    if (!ApiClient.ok(res)) {
      throw ApiException(res.statusCode, ApiClient.errorMessage(res), res.data);
    }
  }

  /// `null` qiymatlarni olib tashlaydi (dio null query paramni ham yuborib
  /// yuborishi mumkin — axios kabi avtomatik tashlab yubormaydi).
  static Map<String, dynamic> _qp(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v != null) out[k] = v;
    });
    return out;
  }

  /* ---------- Profil va guruhlar ---------- */

  static Future<TeacherProfile?> profile() async {
    final res = await ApiClient.dio.get('/teacher/me');
    _check(res);
    final data = res.data;
    return data == null ? null : TeacherProfile.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<TeacherClass>> myClasses() async {
    final res = await ApiClient.dio.get('/teacher/classes');
    _check(res);
    return (res.data as List)
        .map((e) => TeacherClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /* ---------- O'quvchilarni baholash (o'z fanidan) ---------- */

  static Future<List<EvaluationType>> evalTypes() async {
    final res = await ApiClient.dio.get('/teacher/evaluation/types');
    _check(res);
    return (res.data as List)
        .map((e) => EvaluationType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<EvaluationBoard> evalBoard(
    String classId,
    String subjectId, {
    String? month,
  }) async {
    final res = await ApiClient.dio.get(
      '/teacher/evaluation/board',
      queryParameters: _qp({'classId': classId, 'subjectId': subjectId, 'month': month}),
    );
    _check(res);
    return EvaluationBoard.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> setEvalGrade(
    String classId,
    String subjectId,
    String studentId,
    String typeId,
    String month,
    int? score,
  ) async {
    final res = await ApiClient.dio.post('/teacher/evaluation/grade', data: {
      'classId': classId,
      'subjectId': subjectId,
      'studentId': studentId,
      'typeId': typeId,
      'month': month,
      'week': 0,
      'score': score,
    });
    _check(res);
  }

  /* ---------- Topshiriqlar ---------- */

  static Future<List<Assignment>> assignments() async {
    final res = await ApiClient.dio.get('/teacher/assignments');
    _check(res);
    return (res.data as List)
        .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Assignment> createAssignment(SaveAssignmentInput input) async {
    final res = await ApiClient.dio.post('/teacher/assignments', data: input.toJson());
    _check(res);
    return Assignment.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> updateAssignment(String id, SaveAssignmentInput input) async {
    final res = await ApiClient.dio.put('/teacher/assignments/$id', data: input.toJson());
    _check(res);
  }

  static Future<void> deleteAssignment(String id) async {
    final res = await ApiClient.dio.delete('/teacher/assignments/$id');
    _check(res);
  }

  static Future<AssignmentResult> assignmentResults(String id) async {
    final res = await ApiClient.dio.get('/teacher/assignments/$id/results');
    _check(res);
    return AssignmentResult.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> setSubmission(
    String id,
    String studentId,
    bool completed, {
    double? score,
  }) async {
    final res = await ApiClient.dio.put(
      '/teacher/assignments/$id/submissions/$studentId',
      data: {'completed': completed, 'score': score},
    );
    _check(res);
  }

  static Future<MaterialInput> uploadFile(List<int> bytes, String filename) async {
    final fd = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await ApiClient.dio.post('/teacher/uploads', data: fd);
    _check(res);
    return MaterialInput.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<List<AssignmentType>> assignmentTypes() async {
    final res = await ApiClient.dio.get('/teacher/assignment-types');
    _check(res);
    return (res.data as List)
        .map((e) => AssignmentType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /* ---------- Meta ---------- */

  static Future<PortalMeta?> meta() async {
    final res = await ApiClient.dio.get('/teacher/meta');
    _check(res);
    final data = res.data;
    return data == null ? null : PortalMeta.fromJson(data as Map<String, dynamic>);
  }

  static Future<TeacherSchoolInfo> school() async {
    final res = await ApiClient.dio.get('/teacher/school');
    _check(res);
    return TeacherSchoolInfo.fromJson(res.data as Map<String, dynamic>);
  }

  /* ---------- Bildirishnomalar ---------- */

  static Future<NotificationsResponse> notifications() async {
    final res = await ApiClient.dio.get('/teacher/notifications');
    _check(res);
    return NotificationsResponse.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> markNotificationsRead() async {
    final res = await ApiClient.dio.post('/teacher/notifications/read');
    _check(res);
  }

  static Future<void> confirmNotification(String id) async {
    final res = await ApiClient.dio.post('/teacher/notifications/$id/confirm');
    _check(res);
  }

  /// FCM push token'ni backend'ga ro'yxatdan o'tkazish (push yuborish uchun).
  /// Backend: POST /api/teacher/notifications/register (base'da `/api` bor).
  static Future<void> registerPushToken(
    String token,
    String platform, {
    String deviceName = '',
    String appId = '',
  }) async {
    final res = await ApiClient.dio.post('/teacher/notifications/register', data: {
      'token': token,
      'platform': platform,
      'deviceName': deviceName,
      'appId': appId,
    });
    _check(res);
  }

  /// Chiqishda token'ni o'chirish: DELETE /api/teacher/notifications/register?token=...
  static Future<void> unregisterPushToken(String token) async {
    final res = await ApiClient.dio.delete(
      '/teacher/notifications/register',
      queryParameters: {'token': token},
    );
    _check(res);
  }

  /* ---------- Baholash mezonlari (o'z guruhi) ---------- */

  static Future<GradingBoard> gradingBoard(String groupId, {String? month}) async {
    final res = await ApiClient.dio.get(
      '/teacher/grading/group/$groupId/board',
      queryParameters: _qp({'month': month}),
    );
    _check(res);
    return GradingBoard.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> setGrade(SetGrade req) async {
    final res = await ApiClient.dio.post('/teacher/grading/grade', data: req.toJson());
    _check(res);
  }

  static Future<void> bulkGrade(BulkGrade req) async {
    final res = await ApiClient.dio.post('/teacher/grading/grade/bulk', data: req.toJson());
    _check(res);
  }

  /* ---------- Taklif va shikoyat ---------- */

  static Future<void> sendFeedback(
    String type,
    String text, {
    List<int>? imageBytes,
    String? imageName,
  }) async {
    final fd = FormData.fromMap({
      'type': type,
      'text': text,
      if (imageBytes != null)
        'image': MultipartFile.fromBytes(imageBytes, filename: imageName ?? 'image.jpg'),
    });
    final res = await ApiClient.dio.post('/teacher/feedback', data: fd);
    _check(res);
  }

  /* ---------- Maosh (faqat o'ziniki) ---------- */

  static Future<SalaryLedger?> salary({String? from, String? to}) async {
    final res = await ApiClient.dio.get(
      '/teacher/salary',
      queryParameters: _qp({'from': from, 'to': to}),
    );
    _check(res);
    final data = res.data;
    return data == null ? null : SalaryLedger.fromJson(data as Map<String, dynamic>);
  }

  /* ---------- Guruh OYLIK jurnali ---------- */

  static Future<GroupJournal> groupJournal(String classId, {String? month}) async {
    final res = await ApiClient.dio.get(
      '/teacher/journal/group',
      queryParameters: _qp({'classId': classId, 'month': month}),
    );
    _check(res);
    return GroupJournal.fromJson(res.data as Map<String, dynamic>);
  }

  /// Bitta katakni belgilash (baho/davomat/uy vazifa/xulq/o'zlashtirish).
  /// `courseId` = guruh kursi (backend `subjectId`).
  static Future<void> setJournalEntry(
    String classId,
    String courseId,
    String studentId,
    String date, {
    int? grade,
    String? reasonId,
    int? homework,
    int? behavior,
    MasteryLevel? mastery,
    bool present = false,
  }) async {
    final res = await ApiClient.dio.put('/teacher/journal', data: {
      'classId': classId,
      'subjectId': courseId,
      'quarter': 1,
      'studentId': studentId,
      'date': date,
      'period': 1,
      if (grade != null) 'grade': grade,
      if (reasonId != null) 'reasonId': reasonId,
      if (homework != null) 'homework': homework,
      if (behavior != null) 'behavior': behavior,
      if (mastery != null) 'mastery': mastery,
      'present': present,
    });
    _check(res);
  }

  static Future<void> clearJournalEntry(
    String classId,
    String courseId,
    String studentId,
    String date,
  ) async {
    final res = await ApiClient.dio.delete('/teacher/journal', queryParameters: {
      'classId': classId,
      'subjectId': courseId,
      'quarter': 1,
      'studentId': studentId,
      'date': date,
      'period': 1,
    });
    _check(res);
  }

  /// Bitta dars (sana) uchun BARCHA faol o'quvchiga birdan davomat.
  /// absent=false → keldi; true → kelmadi.
  static Future<void> bulkAttendance(
    String classId,
    String subjectId,
    int period,
    List<String> studentIds,
    String date,
    bool absent, {
    String? reasonId,
  }) async {
    final res = await ApiClient.dio.post('/teacher/journal/bulk-attendance', data: {
      'classId': classId,
      'subjectId': subjectId,
      'period': period,
      'studentIds': studentIds,
      'date': date,
      'absent': absent,
      'reasonId': reasonId,
    });
    _check(res);
  }

  /// Bitta darsni BIR MARTALIK boshqa kunga ko'chirish (jurnal ustuni yangi kunga o'tadi).
  static Future<LessonReschedule> rescheduleLesson(
    String classId,
    String fromDate,
    String toDate, {
    String? time,
  }) async {
    final res = await ApiClient.dio.post('/teacher/journal/reschedule', data: {
      'classId': classId,
      'fromDate': fromDate,
      'toDate': toDate,
      if (time != null && time.isNotEmpty) 'time': time,
    });
    _check(res);
    return LessonReschedule.fromJson(res.data as Map<String, dynamic>);
  }

  /// Ko'chirishni bekor qilish — dars asl kuniga qaytadi.
  static Future<void> cancelReschedule(String id) async {
    final res = await ApiClient.dio.delete('/teacher/journal/reschedule/$id');
    _check(res);
  }

  /* ---------- Guruh o'quv dasturi ---------- */

  static Future<GroupCurriculum> groupCurriculum(String groupId) async {
    final res = await ApiClient.dio.get('/teacher/curriculum/group/$groupId');
    _check(res);
    return GroupCurriculum.fromJson(res.data as Map<String, dynamic>);
  }

  static Future<void> setGroupCover(String groupId, String itemId, bool covered) async {
    final res = await ApiClient.dio.post(
      '/teacher/curriculum/group/$groupId/cover',
      data: {'itemId': itemId, 'covered': covered},
    );
    _check(res);
  }

  static Future<void> changeGroupRevision(String groupId, int delta) async {
    final res = await ApiClient.dio.post(
      '/teacher/curriculum/group/$groupId/revision',
      data: {'delta': delta},
    );
    _check(res);
  }

  /* ---------- Guruh chati ---------- */

  static Future<List<String>> chatClasses() async {
    final res = await ApiClient.dio.get('/teacher/chat/classes');
    _check(res);
    return (res.data as List).map((e) => e.toString()).toList();
  }

  static Future<List<ChatMessage>> chat(String className, {String? since}) async {
    final res = await ApiClient.dio.get(
      '/teacher/chat/${Uri.encodeComponent(className)}',
      queryParameters: _qp({'since': since}),
    );
    _check(res);
    return (res.data as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ChatMessage> sendChat(String className, String text) async {
    final res = await ApiClient.dio.post(
      '/teacher/chat/${Uri.encodeComponent(className)}',
      data: {'text': text},
    );
    _check(res);
    return ChatMessage.fromJson(res.data as Map<String, dynamic>);
  }

  /// Har bir kanal uchun oxirgi xabar vaqti (kanal nomi -> ISO vaqt yoki null).
  static Future<Map<String, String?>> lastMessages() async {
    final res = await ApiClient.dio.get('/teacher/chat/last-messages');
    _check(res);
    return Map<String, dynamic>.from(res.data as Map).map((k, v) => MapEntry(k, v as String?));
  }

  /* ---------- O'quvchilar reytingi (o'z guruhlari, ball bo'yicha) ---------- */

  static Future<TeacherRating?> rating() async {
    final res = await ApiClient.dio.get('/teacher/rating');
    _check(res);
    final data = res.data;
    // Tana bo'sh kelishi ham mumkin (204 / bo'sh javob → dio `''` beradi, `null` emas):
    // bunda `as Map` cast xatosi "Reytingni yuklab bo'lmadi" bo'lib ko'rinardi.
    if (data is! Map) return null;
    return TeacherRating.fromJson(Map<String, dynamic>.from(data));
  }

  /* ---------- Test natijalari (o'z guruhlari) ---------- */

  /// Bitta guruhning testlar ro'yxati (sana desc).
  static Future<List<GroupTest>> groupTests(String classId) async {
    final res = await ApiClient.dio.get(
      '/teacher/test-results',
      queryParameters: {'classId': classId},
    );
    _check(res);
    return (res.data as List)
        .map((e) => GroupTest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Test tafsiloti — o'quvchilar + ballari (ball desc).
  static Future<TestResultDetail> testDetail(String id) async {
    final res = await ApiClient.dio.get('/teacher/test-results/$id');
    _check(res);
    return TestResultDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /// Onlayn test savollari faylini yuklash (PDF/rasm, maks 20 MB).
  /// Backend: POST /api/teacher/test-results/uploads (form-data maydoni — `file`).
  static Future<MaterialInput> uploadTestFile(List<int> bytes, String filename) async {
    final fd = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await ApiClient.dio.post('/teacher/test-results/uploads', data: fd);
    _check(res);
    return MaterialInput.fromJson(res.data as Map<String, dynamic>);
  }

  /// Yangi test yaratish (o'z guruhiga). `online` berilsa va `mode`="online" bo'lsa —
  /// onlayn (bot) test: savollar fayli, javob kaliti, vaqt oynasi tekshiriladi va
  /// maksimal ball savollar soniga tenglashtiriladi.
  static Future<GroupTest> createTest({
    required String groupId,
    required String name,
    required String date,
    required double maxScore,
    OnlineTest? online,
  }) async {
    final res = await ApiClient.dio.post('/teacher/test-results', data: {
      'groupId': groupId,
      'name': name,
      'date': date,
      'maxScore': maxScore,
      if (online != null) 'online': online.toJson(),
    });
    _check(res);
    return GroupTest.fromJson(res.data as Map<String, dynamic>);
  }

  /// Testni tahrirlash. `online` berilmasa — testning joriy rejimi SAQLANADI
  /// (onlayn test tasodifan oflaynga aylanib qolmaydi).
  static Future<void> updateTest(
    String id, {
    required String name,
    required String date,
    required double maxScore,
    OnlineTest? online,
  }) async {
    final res = await ApiClient.dio.put('/teacher/test-results/$id', data: {
      'name': name,
      'date': date,
      'maxScore': maxScore,
      if (online != null) 'online': online.toJson(),
    });
    _check(res);
  }

  /// Testni o'chirish (ballari bilan).
  static Future<void> deleteTest(String id) async {
    final res = await ApiClient.dio.delete('/teacher/test-results/$id');
    _check(res);
  }

  /// Bitta o'quvchiga ball qo'yish/tozalash (score=null). Qaytadi: qayta saralangan tafsilot.
  static Future<TestResultDetail> setTestScore(
    String id,
    String studentId,
    double? score,
  ) async {
    final res = await ApiClient.dio.put(
      '/teacher/test-results/$id/scores',
      data: {'studentId': studentId, 'score': score},
    );
    _check(res);
    return TestResultDetail.fromJson(res.data as Map<String, dynamic>);
  }

  /* ---------- Shartnoma (faqat o'ziniki) ---------- */

  /// O'qituvchi bilan tuzilgan shartnomalar (raqam bo'yicha kamayish tartibida).
  /// Faqat superadmin "ilovada ko'rinsin" deb belgilagan yozuvlar qaytadi.
  static Future<List<ContractDoc>> contracts() async {
    final res = await ApiClient.dio.get('/teacher/contracts');
    _check(res);
    final data = res.data;
    // Tana bo'sh kelishi mumkin (204 / bo'sh javob → dio `''` beradi, `null` emas).
    if (data is! List) return <ContractDoc>[];
    return data
        .map((e) => ContractDoc.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
