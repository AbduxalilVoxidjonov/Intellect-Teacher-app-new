// `lib/api/api_client.dart` + `lib/api/teacher_api.dart` uchun birlik testlari.
//
// Tarmoqqa CHIQMAYDI: har bir `setUp` da `ApiClient.dio.httpClientAdapter`
// `FakeAdapter` bilan almashtiriladi (test/helpers/fake_api.dart).
//
// `BUG-Xn (TUZATILDI)` izohli testlar TUZATILGAN xatti-harakatning
// shartnomasini qotirib qo'yadi — regressiya bo'lsa darhol yiqiladi.
// Hozircha bu faylda ochiq (skip qilingan) nuqson qolmagan.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/api/api_client.dart';
import 'package:teacher/api/teacher_api.dart';
import 'package:teacher/models/models.dart';

import 'helpers/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter fake;

  setUp(() {
    fake = FakeAdapter();
    // Haqiqiy transport butunlay almashtiriladi — hech qanday tarmoq chaqiruvi yo'q.
    ApiClient.dio.httpClientAdapter = fake;
    // Global statik holatni testlar orasida tozalaymiz.
    ApiClient.token = null;
    ApiClient.onUnauthorized = null;
  });

  tearDown(() {
    ApiClient.token = null;
    ApiClient.onUnauthorized = null;
    fake.reset();
  });

  /* ==================================================================== */
  /*  A. ApiClient.ok                                                     */
  /* ==================================================================== */

  group('ApiClient.ok', () {
    test('199 — 2xx emas', () => expect(ApiClient.ok(fakeResponse(199)), isFalse));
    test('200 — ok', () => expect(ApiClient.ok(fakeResponse(200)), isTrue));
    test('201 — ok', () => expect(ApiClient.ok(fakeResponse(201)), isTrue));
    test('204 — ok', () => expect(ApiClient.ok(fakeResponse(204)), isTrue));
    test('299 — ok (yuqori chegara)', () => expect(ApiClient.ok(fakeResponse(299)), isTrue));
    test('300 — ok emas (chegaradan tashqari)',
        () => expect(ApiClient.ok(fakeResponse(300)), isFalse));
    test('400 — ok emas', () => expect(ApiClient.ok(fakeResponse(400)), isFalse));
    test('500 — ok emas', () => expect(ApiClient.ok(fakeResponse(500)), isFalse));
    test('statusCode null — 0 deb qaraladi, ok emas',
        () => expect(ApiClient.ok(fakeResponse(null)), isFalse));
  });

  /* ==================================================================== */
  /*  B. ApiClient.errorMessage                                           */
  /* ==================================================================== */

  group('ApiClient.errorMessage — tana ichidagi matnlar', () {
    test("{'message': ...} olinadi", () {
      expect(ApiClient.errorMessage(fakeResponse(400, {'message': 'Xato M'})), 'Xato M');
    });

    test("{'detail': ...} olinadi (ProblemDetails)", () {
      expect(ApiClient.errorMessage(fakeResponse(400, {'detail': 'Xato D'})), 'Xato D');
    });

    test("{'title': ...} olinadi (ProblemDetails)", () {
      expect(ApiClient.errorMessage(fakeResponse(400, {'title': 'Xato T'})), 'Xato T');
    });

    test('ustunlik tartibi: message > detail > title', () {
      expect(
        ApiClient.errorMessage(
            fakeResponse(400, {'message': 'M', 'detail': 'D', 'title': 'T'})),
        'M',
      );
    });

    test('ustunlik tartibi: message yo\'q bo\'lsa detail > title', () {
      expect(ApiClient.errorMessage(fakeResponse(400, {'detail': 'D', 'title': 'T'})), 'D');
    });

    test('message String bo\'lmasa e\'tiborga olinmaydi, keyingisiga o\'tadi', () {
      expect(
        ApiClient.errorMessage(fakeResponse(400, {'message': 42, 'detail': 'D'})),
        'D',
      );
    });

    test('barcha kalitlar String emas — status shoxiga tushadi', () {
      expect(
        ApiClient.errorMessage(fakeResponse(404, {'message': 1, 'detail': 2, 'title': 3})),
        "Ma'lumot topilmadi",
      );
    });

    test('tana Map emas (List) — status shoxiga tushadi', () {
      expect(ApiClient.errorMessage(fakeResponse(404, [1, 2, 3])), "Ma'lumot topilmadi");
    });

    test('tana Map emas (String/HTML) — status shoxiga tushadi', () {
      expect(
        ApiClient.errorMessage(fakeResponse(403, '<html>Forbidden</html>')),
        "Bu amal uchun ruxsat yo'q",
      );
    });

    test('res butunlay null — umumiy xato', () {
      expect(ApiClient.errorMessage(null), 'Xatolik yuz berdi');
    });

    test('res null + fallback — fallback qaytadi', () {
      expect(ApiClient.errorMessage(null, 'FB'), 'FB');
    });
  });

  group('ApiClient.errorMessage — status kodi shoxlari', () {
    test('401', () {
      expect(ApiClient.errorMessage(fakeResponse(401)),
          'Sessiya muddati tugadi — qaytadan kiring');
    });
    test('403', () {
      expect(ApiClient.errorMessage(fakeResponse(403)), "Bu amal uchun ruxsat yo'q");
    });
    test('404', () {
      expect(ApiClient.errorMessage(fakeResponse(404)), "Ma'lumot topilmadi");
    });
    test('413 — fayl chegarasi (yangi shox)', () {
      expect(ApiClient.errorMessage(fakeResponse(413)), 'Fayl juda katta');
    });
    test('429', () {
      expect(ApiClient.errorMessage(fakeResponse(429)),
          "So'rovlar juda tez — bir oz kutib qayta urinib ko'ring");
    });
    test('default (400)', () {
      expect(ApiClient.errorMessage(fakeResponse(400)), 'Xatolik yuz berdi');
    });
    test('default (statusCode null)', () {
      expect(ApiClient.errorMessage(fakeResponse(null)), 'Xatolik yuz berdi');
    });
    test('default (500)', () {
      expect(ApiClient.errorMessage(fakeResponse(500)), 'Xatolik yuz berdi');
    });
  });

  group('ApiClient.errorMessage — fallback', () {
    test('tanasiz 400 + fallback — fallback qaytadi', () {
      expect(ApiClient.errorMessage(fakeResponse(400), 'Maxsus xato'), 'Maxsus xato');
    });

    test('server message fallback\'dan ustun', () {
      expect(
        ApiClient.errorMessage(fakeResponse(400, {'message': 'Server aytdi'}), 'FB'),
        'Server aytdi',
      );
    });

    test('fallback String emas — toString() ishlatiladi', () {
      expect(ApiClient.errorMessage(fakeResponse(400), 12345), '12345');
    });

    // BUG-A1 (TUZATILDI): `fallback` endi status switch'dan KEYIN, faqat
    // notanish status kodi uchun ishlatiladi — login ekranidagi tanasiz 429
    // "Login yoki parol noto'g'ri" emas, rate-limit matnini beradi.
    test("BUG-A1 (TUZATILDI): tanasiz 429 fallback bilan ham rate-limit matnini beradi", () {
      expect(
        ApiClient.errorMessage(fakeResponse(429), "Login yoki parol noto'g'ri"),
        "So'rovlar juda tez — bir oz kutib qayta urinib ko'ring",
      );
    });

    test('BUG-A1 (TUZATILDI): tanasiz 401 fallback bilan ham sessiya matnini beradi', () {
      expect(ApiClient.errorMessage(fakeResponse(401), 'FB'),
          'Sessiya muddati tugadi — qaytadan kiring');
    });

    test('BUG-A1 (TUZATILDI): tanish bo\'lmagan status uchun fallback hamon ishlaydi', () {
      expect(ApiClient.errorMessage(fakeResponse(400), 'FB'), 'FB');
      expect(ApiClient.errorMessage(fakeResponse(500), 'FB'), 'FB');
      expect(ApiClient.errorMessage(fakeResponse(null), 'FB'), 'FB');
    });

    test('server message hamon status matnidan ustun', () {
      expect(
        ApiClient.errorMessage(fakeResponse(429, {'message': 'Server aytdi'}), 'FB'),
        'Server aytdi',
      );
    });
  });

  /* ==================================================================== */
  /*  C. ApiException                                                     */
  /* ==================================================================== */

  group('ApiException', () {
    test('toString() faqat xabarni qaytaradi', () {
      expect(ApiException(401, 'Sessiya tugadi').toString(), 'Sessiya tugadi');
    });

    test('toString() da status kodi yo\'q', () {
      expect(ApiException(404, 'Yo\'q').toString(), isNot(contains('404')));
    });

    test('statusCode saqlanadi', () {
      expect(ApiException(429, 'x').statusCode, 429);
    });

    test('details — status kodi va tanani ko\'rsatadi', () {
      final e = ApiException(400, 'Xato', {'message': 'Xato'});
      expect(e.details, '[400] Xato body={message: Xato}');
    });

    test('details — data null bo\'lsa tanasiz', () {
      expect(ApiException(403, 'Ruxsat yo\'q').details, "[403] Ruxsat yo'q");
    });

    test('details — statusCode null bo\'lsa "-"', () {
      expect(ApiException(null, 'Noma\'lum').details, "[-] Noma'lum");
    });

    test('Exception interfeysini qondiradi', () {
      expect(ApiException(500, 'x'), isA<Exception>());
    });

    // `onError` interceptor'i xatoni FAQAT `DioException` ko'rinishida rad eta
    // oladi, shuning uchun `ApiException` endi undan meros oladi.
    test('DioException dan meros oladi', () {
      expect(ApiException(500, 'x'), isA<DioException>());
    });

    test('DioException.message bilan bir xil matn beradi', () {
      final e = ApiException(500, 'Serverda xatolik');
      expect(e.message, 'Serverda xatolik');
      expect(e.toString(), 'Serverda xatolik');
    });
  });

  /* ==================================================================== */
  /*  D. So'rov interceptor'i                                             */
  /* ==================================================================== */

  group('so\'rov interceptor\'i', () {
    test('token bor — Authorization: Bearer <token> qo\'shiladi', () async {
      ApiClient.token = 'ABC123';
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fake.single.header('Authorization'), 'Bearer ABC123');
    });

    test('token null — Authorization umuman yo\'q', () async {
      ApiClient.token = null;
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fake.single.header('Authorization'), isNull);
    });

    test('Content-Type sukut bo\'yicha application/json', () async {
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fake.single.header('Content-Type'), contains('application/json'));
    });

    test('token o\'zgarsa keyingi so\'rovda yangi token ketadi', () async {
      ApiClient.token = 'T1';
      fake.alwaysJson({});
      await ApiClient.dio.get('/a');
      ApiClient.token = 'T2';
      await ApiClient.dio.get('/b');
      ApiClient.token = null;
      await ApiClient.dio.get('/c');
      expect(fake.requests[0].header('Authorization'), 'Bearer T1');
      expect(fake.requests[1].header('Authorization'), 'Bearer T2');
      expect(fake.requests[2].header('Authorization'), isNull);
    });

    test('TeacherApi chaqiruvlariga ham token biriktiriladi', () async {
      ApiClient.token = 'TK';
      fake.enqueueJson([]);
      await TeacherApi.myClasses();
      expect(fake.single.header('Authorization'), 'Bearer TK');
    });

    test('baseUrl config\'dan olinadi', () async {
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fake.single.uri.toString(), endsWith('/api/teacher/me'));
    });
  });

  /* ==================================================================== */
  /*  E. 401 interceptor'i                                                */
  /* ==================================================================== */

  group('401 interceptor\'i', () {
    test('login\'dan tashqari 401 — onUnauthorized ishga tushadi', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueRaw('', status: 401);
      await ApiClient.dio.get('/teacher/me');
      expect(fired, 1);
    });

    test('/auth/login dagi 401 — onUnauthorized ishlamaydi', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueJson({'message': 'yo\'q'}, status: 401);
      await ApiClient.dio.post('/auth/login', data: {'email': 'a', 'password': 'b'});
      expect(fired, 0);
    });

    // Chiqish paytida push token'ni o'chirish so'rovi tokensiz ketishi mumkin;
    // uning 401'i yana logout'ni qo'zg'asa cheksiz sikl hosil bo'lardi (P0-1).
    test('/notifications/register dagi 401 — onUnauthorized ishlamaydi', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.always(FakeResponse(401, ''));
      await ApiClient.dio.delete('/teacher/notifications/register',
          queryParameters: {'token': 'FCM'});
      await ApiClient.dio.post('/teacher/notifications/register', data: {'token': 'FCM'});
      expect(fired, 0);
    });

    test('200 — onUnauthorized ishlamaydi', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fired, 0);
    });

    test('403 — onUnauthorized ishlamaydi', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueJson({}, status: 403);
      await ApiClient.dio.get('/teacher/me');
      expect(fired, 0);
    });

    test('500 — onUnauthorized ishlamaydi (javob interceptor\'iga yetib bormaydi)', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueJson({}, status: 500);
      await expectLater(ApiClient.dio.get('/teacher/me'), throwsA(isA<DioException>()));
      expect(fired, 0);
    });

    test('onUnauthorized null — 401 da ham yiqilmaydi', () async {
      ApiClient.onUnauthorized = null;
      fake.enqueueRaw('', status: 401);
      final res = await ApiClient.dio.get('/teacher/me');
      expect(res.statusCode, 401);
    });

    test('har bir 401 uchun alohida ishga tushadi (throttling yo\'q)', () async {
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.always(FakeResponse(401, ''));
      await ApiClient.dio.get('/teacher/me');
      await ApiClient.dio.get('/teacher/classes');
      expect(fired, 2);
    });
  });

  /* ==================================================================== */
  /*  F. TeacherApi endpointlari                                          */
  /* ==================================================================== */

  group('TeacherApi — profil va guruhlar', () {
    test('profile() — GET /teacher/me, map qaytaradi', () async {
      fake.enqueueJson({'id': 'u1', 'fullName': 'Ali', 'email': 'a@b.c'});
      final p = await TeacherApi.profile();
      expect(fake.single.method, 'GET');
      expect(fake.single.path, '/teacher/me');
      expect(p!.fullName, 'Ali');
    });

    test('myClasses() — GET /teacher/classes, ro\'yxat qaytaradi', () async {
      fake.enqueueJson([
        {'classId': 'c1', 'className': '9-A', 'grade': 9, 'subjects': []},
        {'classId': 'c2', 'className': '9-B', 'grade': 9, 'subjects': []},
      ]);
      final list = await TeacherApi.myClasses();
      expect(fake.single.method, 'GET');
      expect(fake.single.path, '/teacher/classes');
      expect(list.map((e) => e.className), ['9-A', '9-B']);
    });

    test('school() — GET /teacher/school', () async {
      fake.enqueueJson({'name': 'Intellect', 'telegramChannel': '@ch'});
      final s = await TeacherApi.school();
      expect(fake.single.path, '/teacher/school');
      expect(s.name, 'Intellect');
    });

    test('myClasses() — 403 da ApiException + server message', () async {
      fake.enqueueJson({'message': 'Guruhlar yopiq'}, status: 403);
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Guruhlar yopiq')
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('profile() — tanasiz 401 da lokalizatsiyalangan matn', () async {
      ApiClient.onUnauthorized = () {};
      fake.enqueueRaw('', status: 401);
      await expectLater(
        TeacherApi.profile(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Sessiya muddati tugadi — qaytadan kiring')),
      );
    });
  });

  group('TeacherApi — baholash (mezonlar)', () {
    test('gradingBoard() — yo\'lda groupId, month null tashlanadi', () async {
      fake.enqueueJson({});
      await TeacherApi.gradingBoard('g7');
      expect(fake.single.path, '/teacher/grading/group/g7/board');
      expect(fake.single.queryParameters, isEmpty);
    });
  });

  group('TeacherApi — bildirishnomalar', () {
    test('notifications() — GET, map qaytaradi', () async {
      fake.enqueueJson({
        'unread': 2,
        'items': [
          {'id': 'n1', 'title': 'X'}
        ]
      });
      final r = await TeacherApi.notifications();
      expect(fake.single.path, '/teacher/notifications');
      expect(r.unread, 2);
      expect(r.items.single.title, 'X');
    });

    test('markNotificationsRead() — POST, tanasiz, void', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.markNotificationsRead();
      expect(fake.single.method, 'POST');
      expect(fake.single.path, '/teacher/notifications/read');
      expect(fake.single.data, isNull);
    });

    test('confirmNotification() — POST /teacher/notifications/{id}/confirm', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.confirmNotification('n7');
      expect(fake.single.path, '/teacher/notifications/n7/confirm');
    });

    test('registerPushToken() — POST tanasi (sukut qiymatlar bilan)', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.registerPushToken('fcm-1', 'android');
      expect(fake.single.body,
          {'token': 'fcm-1', 'platform': 'android', 'deviceName': '', 'appId': ''});
    });

    test('unregisterPushToken() — DELETE + query token', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.unregisterPushToken('fcm-1');
      expect(fake.single.method, 'DELETE');
      expect(fake.single.path, '/teacher/notifications/register');
      expect(fake.single.queryParameters, {'token': 'fcm-1'});
    });
  });

  group('TeacherApi — jurnal', () {
    test('groupJournal() — month null tashlanadi', () async {
      fake.enqueueJson({'group': <String, dynamic>{}, 'month': '2024-09'});
      await TeacherApi.groupJournal('c1');
      expect(fake.single.path, '/teacher/journal/group');
      expect(fake.single.queryParameters, {'classId': 'c1'});
    });

    test('setJournalEntry() — ixtiyoriy kalitlarsiz minimal tana', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.setJournalEntry('c1', 'co1', 'st1', '2024-09-02');
      expect(fake.single.method, 'PUT');
      expect(fake.single.path, '/teacher/journal');
      expect(fake.single.body, {
        'classId': 'c1',
        'subjectId': 'co1',
        'quarter': 1,
        'studentId': 'st1',
        'date': '2024-09-02',
        'period': 1,
        'present': false,
      });
      for (final k in ['grade', 'reasonId', 'homework', 'behavior', 'mastery']) {
        expect(fake.single.body.containsKey(k), isFalse, reason: '$k bo\'lmasligi kerak');
      }
    });

    test('setJournalEntry() — barcha ixtiyoriy kalitlar berilsa qo\'shiladi', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.setJournalEntry(
        'c1', 'co1', 'st1', '2024-09-02',
        grade: 5,
        reasonId: 'r1',
        homework: 1,
        behavior: 2,
        mastery: 3,
        present: true,
      );
      expect(fake.single.body['grade'], 5);
      expect(fake.single.body['reasonId'], 'r1');
      expect(fake.single.body['homework'], 1);
      expect(fake.single.body['behavior'], 2);
      expect(fake.single.body['mastery'], 3);
      expect(fake.single.body['present'], isTrue);
    });

    test('setJournalEntry() — grade=0 ham yuboriladi (null emas)', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.setJournalEntry('c1', 'co1', 'st1', '2024-09-02', grade: 0);
      expect(fake.single.body['grade'], 0);
      expect(fake.single.body.containsKey('reasonId'), isFalse);
    });

    test('clearJournalEntry() — DELETE + to\'liq query', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.clearJournalEntry('c1', 'co1', 'st1', '2024-09-02');
      expect(fake.single.method, 'DELETE');
      expect(fake.single.queryParameters, {
        'classId': 'c1',
        'subjectId': 'co1',
        'quarter': 1,
        'studentId': 'st1',
        'date': '2024-09-02',
        'period': 1,
      });
    });

    test('bulkAttendance() — POST, studentIds massivi', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.bulkAttendance('c1', 's1', 2, ['a', 'b'], '2024-09-02', true,
          reasonId: 'r9');
      expect(fake.single.path, '/teacher/journal/bulk-attendance');
      expect(fake.single.body['studentIds'], ['a', 'b']);
      expect(fake.single.body['absent'], isTrue);
      expect(fake.single.body['period'], 2);
      expect(fake.single.body['reasonId'], 'r9');
    });

    test('rescheduleLesson() — time bo\'sh bo\'lsa kalit qo\'shilmaydi', () async {
      fake.enqueueJson({});
      await TeacherApi.rescheduleLesson('c1', '2024-09-02', '2024-09-03', time: '');
      expect(fake.single.body.containsKey('time'), isFalse);
    });

    test('rescheduleLesson() — time berilsa kalit qo\'shiladi', () async {
      fake.enqueueJson({});
      await TeacherApi.rescheduleLesson('c1', '2024-09-02', '2024-09-03', time: '10:00');
      expect(fake.single.body['time'], '10:00');
      expect(fake.single.path, '/teacher/journal/reschedule');
    });

    test('cancelReschedule() — DELETE .../reschedule/{id}', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.cancelReschedule('rs1');
      expect(fake.single.method, 'DELETE');
      expect(fake.single.path, '/teacher/journal/reschedule/rs1');
    });
  });

  group('TeacherApi — o\'quv dasturi', () {
    test('groupCurriculum() — GET yo\'lda groupId', () async {
      fake.enqueueJson({});
      await TeacherApi.groupCurriculum('g1');
      expect(fake.single.path, '/teacher/curriculum/group/g1');
    });

    test('setGroupCover() — POST tanasi', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.setGroupCover('g1', 'i1', true);
      expect(fake.single.path, '/teacher/curriculum/group/g1/cover');
      expect(fake.single.body, {'itemId': 'i1', 'covered': true});
    });

    test('changeGroupRevision() — POST delta', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.changeGroupRevision('g1', -1);
      expect(fake.single.path, '/teacher/curriculum/group/g1/revision');
      expect(fake.single.body, {'delta': -1});
    });
  });

  group('TeacherApi — chat', () {
    test('chatClasses() — GET, String ro\'yxat', () async {
      fake.enqueueJson(['9-A', '9-B']);
      final list = await TeacherApi.chatClasses();
      expect(fake.single.path, '/teacher/chat/classes');
      expect(list, ['9-A', '9-B']);
    });

    test('chatClasses() — raqamlar ham String\'ga aylanadi', () async {
      fake.enqueueJson([1, 2]);
      expect(await TeacherApi.chatClasses(), ['1', '2']);
    });

    test('chat() — sinf nomi URL\'da kodlanadi ("9-A / B")', () async {
      fake.enqueueJson([]);
      await TeacherApi.chat('9-A / B');
      expect(fake.single.path, '/teacher/chat/9-A%20%2F%20B');
      expect(fake.single.uri.path, '/api/teacher/chat/9-A%20%2F%20B');
      // Dekodlangan holda — server aynan shu sinf nomini oladi.
      expect(fake.single.pathSegments.last, '9-A / B');
      expect(fake.single.queryParameters, isEmpty);
    });

    test('chat(since:) — query qo\'shiladi', () async {
      fake.enqueueJson([
        {'id': 'm1', 'text': 'salom'}
      ]);
      final msgs = await TeacherApi.chat('9-A', since: '2024-09-02T10:00:00Z');
      expect(fake.single.queryParameters, {'since': '2024-09-02T10:00:00Z'});
      expect(msgs.single.text, 'salom');
    });

    test('sendChat() — POST kodlangan yo\'l + text tanasi', () async {
      fake.enqueueJson({'id': 'm2', 'text': 'javob'}, status: 201);
      final m = await TeacherApi.sendChat('9-A / B', 'javob');
      expect(fake.single.method, 'POST');
      expect(fake.single.path, '/teacher/chat/9-A%20%2F%20B');
      expect(fake.single.body, {'text': 'javob'});
      expect(m.text, 'javob');
    });

    test('sendChat() — 400 da ApiException server message bilan', () async {
      fake.enqueueJson({'message': 'Chat yopilgan'}, status: 400);
      await expectLater(
        TeacherApi.sendChat('9-A', 'x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Chat yopilgan')),
      );
    });

    test('lastMessages() — kanal -> vaqt map\'i (null qiymat bilan)', () async {
      fake.enqueueJson({'9-A': '2024-09-02T10:00:00Z', '9-B': null});
      final m = await TeacherApi.lastMessages();
      expect(fake.single.path, '/teacher/chat/last-messages');
      expect(m, {'9-A': '2024-09-02T10:00:00Z', '9-B': null});
    });
  });

  group('TeacherApi — test natijalari', () {
    test('groupTests() — GET + classId query', () async {
      fake.enqueueJson([
        {'id': 't1', 'name': 'Test 1'}
      ]);
      final list = await TeacherApi.groupTests('c1');
      expect(fake.single.path, '/teacher/test-results');
      expect(fake.single.queryParameters, {'classId': 'c1'});
      expect(list.single.name, 'Test 1');
    });

    test('testDetail() — GET /teacher/test-results/{id}', () async {
      fake.enqueueJson({});
      await TeacherApi.testDetail('t1');
      expect(fake.single.path, '/teacher/test-results/t1');
    });

    test('createTest() — online berilmasa kalit yo\'q', () async {
      fake.enqueueJson({'id': 't2'}, status: 201);
      await TeacherApi.createTest(
          groupId: 'g1', name: 'T', date: '2024-09-02', maxScore: 20);
      expect(fake.single.method, 'POST');
      expect(fake.single.body, {
        'groupId': 'g1',
        'name': 'T',
        'date': '2024-09-02',
        'maxScore': 20.0,
      });
      expect(fake.single.body.containsKey('online'), isFalse);
    });

    test('updateTest() — PUT, online berilmasa kalit yo\'q', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.updateTest('t2', name: 'T2', date: '2024-09-03', maxScore: 30);
      expect(fake.single.method, 'PUT');
      expect(fake.single.path, '/teacher/test-results/t2');
      expect(fake.single.body.containsKey('online'), isFalse);
      expect(fake.single.body['maxScore'], 30.0);
    });

    test('deleteTest() — DELETE', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.deleteTest('t2');
      expect(fake.single.method, 'DELETE');
      expect(fake.single.path, '/teacher/test-results/t2');
    });

    test('setTestScore() — PUT .../scores, score null tozalash', () async {
      fake.enqueueJson({});
      await TeacherApi.setTestScore('t2', 'st1', null);
      expect(fake.single.path, '/teacher/test-results/t2/scores');
      expect(fake.single.body, {'studentId': 'st1', 'score': null});
    });

    test('uploadTestFile() — POST /teacher/test-results/uploads multipart', () async {
      fake.enqueueJson({'url': '/uploads/q.pdf'});
      await TeacherApi.uploadTestFile([9, 9], 'q.pdf');
      expect(fake.single.path, '/teacher/test-results/uploads');
      expect(fake.single.data, isA<FormData>());
    });
  });

  /* ==================================================================== */
  /*  "Bog'lanish kerak" — guruh jurnalidagi «Aloqa» tabi                 */
  /* ==================================================================== */

  group('TeacherApi — bog\'lanish navbati', () {
    test('contactReasons() — GET /teacher/contact-reasons', () async {
      fake.enqueueJson([
        {'id': 'r1', 'category': 'contact', 'label': "To'lov kechikdi", 'order': 1},
      ]);
      final list = await TeacherApi.contactReasons();
      expect(fake.single.method, 'GET');
      expect(fake.single.path, '/teacher/contact-reasons');
      expect(list.single.id, 'r1');
      expect(list.single.label, "To'lov kechikdi");
    });

    test('sendToContactQueue() — POST guruh yo\'liga, SANA YUBORILMAYDI', () async {
      fake.enqueueJson({'created': 2, 'skipped': 0, 'skippedNames': [], 'notFound': 0});
      final r = await TeacherApi.sendToContactQueue(
          'g1', ['st1', 'st2'], 'r1', 'darsga kelmadi');
      expect(fake.single.method, 'POST');
      expect(fake.single.path, '/teacher/groups/g1/contacts');
      expect(fake.single.body, {
        'studentIds': ['st1', 'st2'],
        'reasonId': 'r1',
        'note': 'darsga kelmadi',
      });
      // Rejalashtirish operatorning ishi — tanada sana bo'lmasligi SHART.
      expect(fake.single.body.containsKey('due'), isFalse);
      expect(fake.single.body.containsKey('dueDate'), isFalse);
      expect(r.created, 2);
    });

    test('sendToContactQueue() — guruh id si yo\'lda kodlanadi', () async {
      fake.enqueueJson({'created': 0, 'skipped': 0, 'skippedNames': [], 'notFound': 0});
      await TeacherApi.sendToContactQueue('g 1/2', ['st1'], 'r1', 'izoh');
      expect(fake.single.path, '/teacher/groups/g%201%2F2/contacts');
    });

    test('sendToContactQueue() — chetlab o\'tilganlar javobda qaytadi', () async {
      fake.enqueueJson({
        'created': 1,
        'skipped': 2,
        'skippedNames': ['Ali', 'Vali'],
        'notFound': 3,
      });
      final r = await TeacherApi.sendToContactQueue('g1', ['a', 'b', 'c'], 'r1', 'izoh');
      expect(r.created, 1);
      expect(r.skipped, 2);
      expect(r.skippedNames, ['Ali', 'Vali']);
      expect(r.notFound, 3);
    });

    test('sendToContactQueue() — 400 da serverning matni chiqadi', () async {
      fake.enqueueJson({'message': "O'quvchi tanlanmagan"}, status: 400);
      await expectLater(
        TeacherApi.sendToContactQueue('g1', [], 'r1', 'izoh'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', "O'quvchi tanlanmagan")),
      );
    });
  });

  group('TeacherApi — maosh, reyting, shartnoma, feedback', () {
    test('salary(from,to) — ikkala query ham ketadi', () async {
      fake.enqueueJson({});
      await TeacherApi.salary(from: '2024-01', to: '2024-09');
      expect(fake.single.path, '/teacher/salary');
      expect(fake.single.queryParameters, {'from': '2024-01', 'to': '2024-09'});
    });

    test('salary(from: null, to: null) — _qp hammasini tashlaydi', () async {
      fake.enqueueJson({});
      await TeacherApi.salary();
      expect(fake.single.queryParameters, isEmpty);
      expect(fake.single.uri.hasQuery, isFalse);
      expect(fake.single.uri.toString(), endsWith('/api/teacher/salary'));
    });

    test('salary() — 403 da ApiException', () async {
      fake.enqueueJson({'message': 'Maosh yopiq'}, status: 403);
      await expectLater(
        TeacherApi.salary(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Maosh yopiq')),
      );
    });

    test('rating() — bo\'sh tana (204) qorovuli null qaytaradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.rating(), isNull);
      expect(fake.single.path, '/teacher/rating');
    });

    test('rating() — bo\'sh JSON tana ham null (data null)', () async {
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.rating(), isNull);
    });

    test('rating() — Map kelsa parse qilinadi', () async {
      fake.enqueueJson({'teacherId': 'u1', 'fullName': 'Ali', 'averageBall': 4.5, 'rows': []});
      final r = await TeacherApi.rating();
      expect(r!.fullName, 'Ali');
      expect(r.averageBall, 4.5);
    });

    test('contracts() — bo\'sh tana (204) qorovuli bo\'sh ro\'yxat', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.contracts(), isEmpty);
      expect(fake.single.path, '/teacher/contracts');
    });

    test('contracts() — List kelsa parse qilinadi', () async {
      fake.enqueueJson([
        {'id': 'k1', 'number': 12, 'title': 'Shartnoma № 12'}
      ]);
      final list = await TeacherApi.contracts();
      expect(list.single.number, 12);
    });

    test('meta() — GET /teacher/meta', () async {
      fake.enqueueJson({'quarters': [], 'absenceReasons': []});
      await TeacherApi.meta();
      expect(fake.single.path, '/teacher/meta');
    });

    test('sendFeedback() — rasmsiz multipart', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.sendFeedback('taklif', 'yaxshi');
      expect(fake.single.method, 'POST');
      expect(fake.single.path, '/teacher/feedback');
      expect(fake.single.data, isA<FormData>());
      expect(fake.single.bodyText, contains('yaxshi'));
      expect(fake.single.bodyText, isNot(contains('filename')));
    });

    test('sendFeedback() — rasm bilan multipart', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.sendFeedback('shikoyat', 'yomon',
          imageBytes: [1, 2, 3], imageName: 'p.jpg');
      expect(fake.single.bodyText, contains('p.jpg'));
    });

    test('setGrade() / bulkGrade() — POST yo\'llari', () async {
      fake.always(FakeResponse(204, '', contentType: null));
      await TeacherApi.setGrade(SetGrade(
          groupId: 'g1',
          studentId: 's1',
          criterionId: 'cr1',
          date: '2024-09-02',
          done: true));
      expect(fake.requests[0].path, '/teacher/grading/grade');
      expect(fake.requests[0].body['done'], isTrue);
      await TeacherApi.bulkGrade(BulkGrade(
          groupId: 'g1', criterionId: 'cr1', date: '2024-09-02', done: false));
      expect(fake.requests[1].path, '/teacher/grading/grade/bulk');
    });
  });

  /* ==================================================================== */
  /*  Tasdiqlangan nuqsonlar (BUG-A3 / A4 / A5 / A7)                      */
  /* ==================================================================== */

  group('nuqsonlar — 5xx va bo\'sh tana', () {
    // BUG-A3 (TUZATILDI): `onError` interceptor'i dio'ning HAR QANDAY xatosini
    // o'zbekcha matnli `ApiException` ga o'raydi. `ApiException` `DioException`
    // dan meros olgani uchun test'da ANIQ tur tekshiriladi.
    test('BUG-A3 (TUZATILDI): 500 — server message\'li ApiException', () async {
      fake.enqueueJson({'message': 'Server yiqildi'}, status: 500);
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Server yiqildi')),
      );
    });

    test('BUG-A3 (TUZATILDI): 502 HTML sahifa — o\'zbekcha ApiException', () async {
      fake.enqueueRaw('<html>Bad Gateway</html>', status: 502, contentType: 'text/html');
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.message, 'message',
                "Serverda xatolik — birozdan so'ng qayta urinib ko'ring")),
      );
    });

    test('BUG-A3 (TUZATILDI): 502 matnida inglizcha dio matni yo\'q', () async {
      fake.enqueueRaw('<html>Bad Gateway</html>', status: 502, contentType: 'text/html');
      Object? caught;
      try {
        await TeacherApi.myClasses();
      } catch (e) {
        caught = e;
      }
      // Ekranlar `e.toString()` ni to'g'ridan-to'g'ri SnackBar ga chiqaradi.
      expect(caught.toString(), "Serverda xatolik — birozdan so'ng qayta urinib ko'ring");
      expect(caught.toString(), isNot(contains('DioException')));
      expect(caught.toString(), isNot(contains('status code')));
    });

    test('BUG-A3 (TUZATILDI): timeout — "Server javob bermadi" matni', () async {
      fake.enqueue(FakeResponse(0, '',
          error: DioException.receiveTimeout(
              timeout: const Duration(seconds: 1),
              requestOptions: RequestOptions(path: '/teacher/classes'))));
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.message, 'message',
                'Server javob bermadi — internetni tekshirib qayta urining')),
      );
    });

    test('BUG-A3 (TUZATILDI): tarmoq uzildi — "Serverga ulanib bo\'lmadi"', () async {
      fake.enqueue(FakeResponse(0, '',
          error: DioException.connectionError(
              requestOptions: RequestOptions(path: '/teacher/classes'),
              reason: 'no internet')));
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', 'Serverga ulanib bo\'lmadi. Internetni tekshiring.')),
      );
    });

    test('BUG-A3 (TUZATILDI): 4xx dagi ApiException qayta o\'ralmaydi', () async {
      // `_check()` o'zi otgan `ApiException` `onError` dan o'tmaydi (dio uni
      // interceptor'dan KEYIN, ya'ni javob qaytgach otadi) — matn o'zgarmaydi.
      fake.enqueueJson({'message': 'Guruhlar yopiq'}, status: 403);
      await expectLater(
        TeacherApi.myClasses(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'Guruhlar yopiq')),
      );
    });

    // BUG-A4 (TUZATILDI): `_asMapOrNull` bo'sh tanani (`''` ham, `null` ham)
    // `null` ga aylantiradi — avval faqat `data == null` tekshirilardi.
    test('BUG-A4 (TUZATILDI): 204 (content-type\'siz) da profile() null qaytaradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.profile(), isNull);
    });

    test('BUG-A4 (TUZATILDI): 204 (content-type\'siz) da meta() null qaytaradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.meta(), isNull);
    });

    test('BUG-A4 (TUZATILDI): 204 (content-type\'siz) da salary() null qaytaradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.salary(), isNull);
    });

    test('BUG-A4 (TUZATILDI): JSON content-type\'li bo\'sh tana ham null', () async {
      // dio bo'sh tanani content-type'ga qarab `''` YOKI `null` beradi —
      // ikkala variant ham qoplanadi.
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.profile(), isNull);
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.meta(), isNull);
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.salary(), isNull);
    });

    // BUG-A5 (TUZATILDI): `_asList`/`_asMap` yordamchilari qorovulsiz
    // cast'lar o'rnini egalladi.
    test('BUG-A5 (TUZATILDI): myClasses() bo\'sh tanada bo\'sh ro\'yxat beradi', () async {
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.myClasses(), isEmpty);
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.myClasses(), isEmpty);
    });

    test('BUG-A5 (TUZATILDI): chatClasses() bo\'sh tanada bo\'sh ro\'yxat beradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.chatClasses(), isEmpty);
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.chatClasses(), isEmpty);
    });

    test('BUG-A5 (TUZATILDI): contactReasons() bo\'sh tanada bo\'sh ro\'yxat beradi', () async {
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.contactReasons(), isEmpty);
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.contactReasons(), isEmpty);
    });

    test('BUG-A5 (TUZATILDI): notifications() bo\'sh tanada bo\'sh model beradi', () async {
      fake.enqueueEmpty(status: 200);
      var r = await TeacherApi.notifications();
      expect(r.unread, 0);
      expect(r.items, isEmpty);
      fake.enqueue(FakeResponse(204, '', contentType: null));
      r = await TeacherApi.notifications();
      expect(r.items, isEmpty);
    });

    test('BUG-A5 (TUZATILDI): _asList Map/String kelganda ham yiqilmaydi', () async {
      fake.enqueueJson({'items': []}); // ro'yxat kutilgan joyda Map keldi
      expect(await TeacherApi.myClasses(), isEmpty);
      fake.enqueueRaw('<html>xato</html>', contentType: 'text/html');
      expect(await TeacherApi.chatClasses(), isEmpty);
    });

    test('BUG-A5 (TUZATILDI): _asMap List/String kelganda bo\'sh model beradi', () async {
      fake.enqueueJson([]); // Map kutilgan joyda ro'yxat keldi
      expect((await TeacherApi.school()).name, '');
      fake.enqueueRaw('<html>xato</html>', contentType: 'text/html');
      expect((await TeacherApi.groupJournal('g1', month: '2026-08')).group.id, '');
    });

    test('BUG-A5 (TUZATILDI): _asMap String bo\'lmagan kalitlarni ham o\'qiydi', () async {
      // `Map<String,dynamic>.from` bunda yiqilardi — endi kalit `toString()` bo'ladi.
      fake.enqueueJson({'name': 'Intellect'});
      expect((await TeacherApi.school()).name, 'Intellect');
    });

    // BUG-A7 (TUZATILDI): `lastMessages()` `v?.toString()` ishlatadi.
    test('BUG-A7 (TUZATILDI): raqamli qiymat String\'ga aylanadi', () async {
      fake.enqueueJson({'9-A': '2024-09-02T10:00:00Z', '9-B': 5});
      expect(await TeacherApi.lastMessages(), {'9-A': '2024-09-02T10:00:00Z', '9-B': '5'});
    });

    test('BUG-A7 (TUZATILDI): null qiymat null bo\'lib qoladi', () async {
      fake.enqueueJson({'9-A': null});
      expect(await TeacherApi.lastMessages(), {'9-A': null});
    });

    test('BUG-A7 (TUZATILDI): bo\'sh tanada bo\'sh map', () async {
      fake.enqueueEmpty(status: 200);
      expect(await TeacherApi.lastMessages(), isEmpty);
      fake.enqueue(FakeResponse(204, '', contentType: null));
      expect(await TeacherApi.lastMessages(), isEmpty);
    });
  });

  /* ==================================================================== */
  /*  Fayl yuklash chegarasi (yangi qorovul)                              */
  /* ==================================================================== */

  group('fayl yuklash chegarasi', () {
    // Backend `UploadGuard` chegarasi 20 MB. Mijozda tekshirilmasa foydalanuvchi
    // butun faylni yuklab bo'lgach 413 oladi.
    List<int> bytes(int n) => List<int>.filled(n, 1);

    test('uploadTestFile() — 20 MB dan katta fayl 413 ApiException beradi', () async {
      await expectLater(
        TeacherApi.uploadTestFile(bytes(20 * 1024 * 1024 + 1), 'katta.pdf'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 413)
            .having((e) => e.message, 'message', "Fayl 20 MB dan katta bo'lmasligi kerak")),
      );
      expect(fake.count, 0, reason: "so'rov umuman yuborilmasligi kerak");
    });

    test('sendFeedback() — katta rasm ham 413 beradi', () async {
      await expectLater(
        TeacherApi.sendFeedback('shikoyat', 'matn',
            imageBytes: bytes(20 * 1024 * 1024 + 1), imageName: 'p.jpg'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 413)),
      );
      expect(fake.count, 0);
    });

    test('aniq 20 MB — chegara ichida, so\'rov ketadi', () async {
      fake.enqueueJson({'url': '/uploads/a.pdf', 'name': 'a.pdf'});
      await TeacherApi.uploadTestFile(bytes(20 * 1024 * 1024), 'a.pdf');
      expect(fake.count, 1);
      expect(fake.single.path, '/teacher/test-results/uploads');
    });

    test('bo\'sh fayl — statuskodsiz "Fayl bo\'sh"', () async {
      await expectLater(
        TeacherApi.uploadTestFile(const <int>[], 'bosh.pdf'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', isNull)
            .having((e) => e.message, 'message', "Fayl bo'sh")),
      );
      expect(fake.count, 0);
    });

    test('sendFeedback() rasmsiz — chegara tekshiruvi o\'tkazib yuboriladi', () async {
      fake.enqueueEmpty(status: 204);
      await TeacherApi.sendFeedback('taklif', 'yaxshi');
      expect(fake.count, 1);
    });
  });

  /* ==================================================================== */
  /*  Testlar tarmoqqa chiqmasligi                                        */
  /* ==================================================================== */

  test('soxta adapter har doim o\'rnatilgan — haqiqiy tarmoq ishlatilmaydi', () async {
    expect(ApiClient.dio.httpClientAdapter, same(fake));
    fake.enqueueJson({});
    await ApiClient.dio.get('/teacher/me');
    expect(fake.count, 1);
  });
}
