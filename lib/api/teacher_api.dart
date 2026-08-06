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

  /* ---------- Javob tanasini xavfsiz o'qish ---------- */
  //
  // DIQQAT: 2xx bo'lgani javob tanasi JSON degani emas. dio bo'sh tanani
  // content-type'ga qarab `''` (ASP.NET `NoContent()` — content-type yo'q)
  // yoki `null` (content-type JSON) qilib beradi. Xom `as List`/`as Map`
  // cast'lari HAR IKKALA holatda ham `TypeError` berardi — bu `Error`, ya'ni
  // ekranlardagi `on ApiException` uni tutmaydi va o'qituvchi
  // "type 'String' is not a subtype of type 'Map'" matnini ko'rardi.

  /// Ro'yxat bo'lmasa — bo'sh ro'yxat.
  static List<dynamic> _asList(dynamic d) => d is List ? d : const <dynamic>[];

  /// Map bo'lmasa — bo'sh map (barcha `fromJson` bo'sh map bilan ishlay oladi,
  /// chunki hamma maydon `_s`/`_i`/`_d` yordamchilaridan o'tadi).
  static Map<String, dynamic> _asMap(dynamic d) {
    if (d is! Map) return const <String, dynamic>{};
    final out = <String, dynamic>{};
    d.forEach((k, v) => out[k.toString()] = v);
    return out;
  }

  /// Tana bo'sh bo'lsa `null` — chaqiruvchi "ma'lumot yo'q" holatini ko'rsatadi.
  static Map<String, dynamic>? _asMapOrNull(dynamic d) =>
      d is Map ? _asMap(d) : null;

  /* ---------- Fayl yuklash chegarasi ---------- */

  /// Backend `UploadGuard` chegarasi. Mijozda tekshirilmasa, foydalanuvchi
  /// katta faylni to'liq yuklab bo'lgach 413 oladi va (413 uchun matn
  /// bo'lmagani sababli) "Xatolik yuz berdi" ko'radi. Android'da native
  /// tanlagichda tekshiruv bor, iOS/galereya yo'lida esa umuman yo'q edi.
  static const int _kMaxUploadBytes = 20 * 1024 * 1024;

  static void _checkSize(List<int> bytes) {
    if (bytes.isEmpty) {
      throw ApiException(null, "Fayl bo'sh");
    }
    if (bytes.length > _kMaxUploadBytes) {
      throw ApiException(413, "Fayl 20 MB dan katta bo'lmasligi kerak");
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
    // `data == null` qorovuli yetarli emas edi: HAQIQIY 204 da dio `''` beradi.
    final data = _asMapOrNull(res.data);
    return data == null ? null : TeacherProfile.fromJson(data);
  }

  static Future<List<TeacherClass>> myClasses() async {
    final res = await ApiClient.dio.get('/teacher/classes');
    _check(res);
    return _asList(res.data)
        .map((e) => TeacherClass.fromJson(_asMap(e)))
        .toList();
  }

  /* ---------- Meta ---------- */

  static Future<PortalMeta?> meta() async {
    final res = await ApiClient.dio.get('/teacher/meta');
    _check(res);
    final data = _asMapOrNull(res.data);
    return data == null ? null : PortalMeta.fromJson(data);
  }

  static Future<TeacherSchoolInfo> school() async {
    final res = await ApiClient.dio.get('/teacher/school');
    _check(res);
    return TeacherSchoolInfo.fromJson(_asMap(res.data));
  }

  /* ---------- Bildirishnomalar ---------- */

  static Future<NotificationsResponse> notifications() async {
    final res = await ApiClient.dio.get('/teacher/notifications');
    _check(res);
    return NotificationsResponse.fromJson(_asMap(res.data));
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
    return GradingBoard.fromJson(_asMap(res.data));
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
    if (imageBytes != null) _checkSize(imageBytes);
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
    final data = _asMapOrNull(res.data);
    return data == null ? null : SalaryLedger.fromJson(data);
  }

  /* ---------- Guruh OYLIK jurnali ---------- */

  static Future<GroupJournal> groupJournal(String classId, {String? month}) async {
    final res = await ApiClient.dio.get(
      '/teacher/journal/group',
      queryParameters: _qp({'classId': classId, 'month': month}),
    );
    _check(res);
    return GroupJournal.fromJson(_asMap(res.data));
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
    return LessonReschedule.fromJson(_asMap(res.data));
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
    return GroupCurriculum.fromJson(_asMap(res.data));
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
    return _asList(res.data).map((e) => e.toString()).toList();
  }

  static Future<List<ChatMessage>> chat(String className, {String? since}) async {
    final res = await ApiClient.dio.get(
      '/teacher/chat/${Uri.encodeComponent(className)}',
      queryParameters: _qp({'since': since}),
    );
    _check(res);
    return _asList(res.data)
        .map((e) => ChatMessage.fromJson(_asMap(e)))
        .toList();
  }

  static Future<ChatMessage> sendChat(String className, String text) async {
    final res = await ApiClient.dio.post(
      '/teacher/chat/${Uri.encodeComponent(className)}',
      data: {'text': text},
    );
    _check(res);
    return ChatMessage.fromJson(_asMap(res.data));
  }

  /// Har bir kanal uchun oxirgi xabar vaqti (kanal nomi -> ISO vaqt yoki null).
  static Future<Map<String, String?>> lastMessages() async {
    final res = await ApiClient.dio.get('/teacher/chat/last-messages');
    _check(res);
    // `v as String?` raqamli qiymatda yiqilardi — `toString()` xavfsizroq.
    return _asMap(res.data).map((k, v) => MapEntry(k, v?.toString()));
  }

  /* ---------- O'quvchilar reytingi (o'z guruhlari, ball bo'yicha) ---------- */

  static Future<TeacherRating?> rating() async {
    final res = await ApiClient.dio.get('/teacher/rating');
    _check(res);
    final data = res.data;
    // Tana bo'sh kelishi ham mumkin (204 / bo'sh javob → dio `''` beradi, `null` emas):
    // bunda `as Map` cast xatosi "Reytingni yuklab bo'lmadi" bo'lib ko'rinardi.
    if (data is! Map) return null;
    return TeacherRating.fromJson(_asMap(data));
  }

  /* ---------- Test natijalari (o'z guruhlari) ---------- */

  /// Bitta guruhning testlar ro'yxati (sana desc).
  static Future<List<GroupTest>> groupTests(String classId) async {
    final res = await ApiClient.dio.get(
      '/teacher/test-results',
      queryParameters: {'classId': classId},
    );
    _check(res);
    return _asList(res.data)
        .map((e) => GroupTest.fromJson(_asMap(e)))
        .toList();
  }

  /// Test tafsiloti — o'quvchilar + ballari (ball desc).
  static Future<TestResultDetail> testDetail(String id) async {
    final res = await ApiClient.dio.get('/teacher/test-results/$id');
    _check(res);
    return TestResultDetail.fromJson(_asMap(res.data));
  }

  /// Onlayn test savollari faylini yuklash (PDF/rasm, maks 20 MB).
  /// Backend: POST /api/teacher/test-results/uploads (form-data maydoni — `file`).
  static Future<MaterialInput> uploadTestFile(List<int> bytes, String filename) async {
    _checkSize(bytes);
    final fd = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await ApiClient.dio.post('/teacher/test-results/uploads', data: fd);
    _check(res);
    return MaterialInput.fromJson(_asMap(res.data));
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
    return GroupTest.fromJson(_asMap(res.data));
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
    return TestResultDetail.fromJson(_asMap(res.data));
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
        .map((e) => ContractDoc.fromJson(_asMap(e)))
        .toList();
  }

  /* ---------- "Bog'lanish kerak" (guruh jurnalidagi «Aloqa» tabi) ---------- */

  /// Bog'lanish sabablari katalogi (Sozlamalar → Sabablar, kategoriya "contact").
  /// Admin endpointi (`/api/admin/action-reasons`) o'qituvchiga YOPIQ, shuning
  /// uchun alohida marshrut bor.
  static Future<List<ContactReason>> contactReasons() async {
    final res = await ApiClient.dio.get('/teacher/contact-reasons');
    _check(res);
    return _asList(res.data)
        .map((e) => ContactReason.fromJson(_asMap(e)))
        .toList();
  }

  /// O'z guruhidagi o'quvchilarni "Bog'lanish kerak" navbatiga yuboradi.
  ///
  /// SANA YUBORILMAYDI — talab darhol navbatga tushadi (bugungi ish);
  /// rejalashtirish (qayta qo'ng'iroq sanasi) operatorning ishi.
  /// Sabab va izoh tanlanganlarning HAMMASIGA bir xil qo'yiladi.
  static Future<ContactBulkResult> sendToContactQueue(
    String classId,
    List<String> studentIds,
    String reasonId,
    String note,
  ) async {
    final res = await ApiClient.dio.post(
      '/teacher/groups/${Uri.encodeComponent(classId)}/contacts',
      data: {'studentIds': studentIds, 'reasonId': reasonId, 'note': note},
    );
    _check(res);
    return ContactBulkResult.fromJson(_asMap(res.data));
  }
}
