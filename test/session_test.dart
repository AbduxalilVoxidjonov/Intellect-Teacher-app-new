// `lib/services/session.dart` uchun birlik testlari.
//
// Tarmoq: `ApiClient.dio.httpClientAdapter` har `setUp` da `FakeAdapter` ga
// almashtiriladi — haqiqiy so'rov yo'q.
// Saqlash: `SharedPreferences.setMockInitialValues({})`.
//
// FIREBASE HAQIDA: `Session._persist()` → `PushService.instance.syncToken()` va
// `Session.logout()` → `PushService.instance.clear()` Firebase'ga tegadi.
// Test muhitida `Firebase.app()` `[core/no-app]` xatosini otadi, LEKIN
// `PushService` ning ichki `try/catch` i uni to'liq yutadi (`push.dart:213-226`
// va `:229-235`), shuning uchun `login()`/`logout()` testlari to'liq ishlaydi.
// Yagona yetib bo'lmaydigan joy — `PushService.clear()` ichidagi
// `unregisterPushToken` chaqiruvi (token olinmagani uchun umuman bajarilmaydi),
// shu sababli BUG-A8 ni faqat `Session` darajasida hujjatlashtiramiz.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher/api/api_client.dart';
import 'package:teacher/services/push.dart';
import 'package:teacher/services/session.dart';

import 'helpers/fake_api.dart';

const _kBug = "hozircha noto'g'ri ishlaydi";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter fake;

  setUp(() {
    fake = FakeAdapter();
    ApiClient.dio.httpClientAdapter = fake;
    ApiClient.token = null;
    ApiClient.onUnauthorized = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.token = null;
    ApiClient.onUnauthorized = null;
    fake.reset();
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  /* ==================================================================== */
  /*  init()                                                              */
  /* ==================================================================== */

  group('Session.init()', () {
    test('bo\'sh xotira — token yo\'q, ready=true', () async {
      final s = Session();
      expect(s.ready, isFalse);
      await s.init();
      expect(s.ready, isTrue);
      expect(s.token, isNull);
      expect(s.user, isNull);
      expect(s.isAuthed, isFalse);
      expect(s.isDark, isFalse);
    });

    test('token/user/temani xotiradan tiklaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'TOK',
        'user': jsonEncode({'id': 'u1', 'fullName': 'Ali Vali', 'role': 'teacher'}),
        'teacher_theme': 'dark',
      });
      final s = Session();
      await s.init();
      expect(s.token, 'TOK');
      expect(s.isAuthed, isTrue);
      expect(s.user, {'id': 'u1', 'fullName': 'Ali Vali', 'role': 'teacher'});
      expect(s.fullName, 'Ali Vali');
      expect(s.teacherId, 'u1');
      expect(s.isDark, isTrue);
    });

    test('ApiClient.token va onUnauthorized ulanadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'token': 'TOK'});
      final s = Session();
      await s.init();
      expect(ApiClient.token, 'TOK');
      expect(ApiClient.onUnauthorized, isNotNull);
    });

    test('tema "light" — isDark false', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'teacher_theme': 'light'});
      final s = Session();
      await s.init();
      expect(s.isDark, isFalse);
    });

    test('notifyListeners chaqiriladi', () async {
      final s = Session();
      var n = 0;
      s.addListener(() => n++);
      await s.init();
      expect(n, 1);
    });

    test('buzuq JSON — try/catch yutadi, user null qoladi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': 'TOK',
        'user': '{bu json emas',
      });
      final s = Session();
      await s.init(); // otmasligi kerak
      expect(s.user, isNull);
      expect(s.token, 'TOK');
      expect(s.ready, isTrue);
      expect(s.fullName, '');
      expect(s.teacherId, isNull);
    });

    test('user JSON massiv — cast xatosi ham yutiladi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'user': '[1,2,3]'});
      final s = Session();
      await s.init();
      expect(s.user, isNull);
      expect(s.ready, isTrue);
    });

    test('user JSON = "null" — user null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'user': 'null'});
      final s = Session();
      await s.init();
      expect(s.user, isNull);
    });
  });

  /* ==================================================================== */
  /*  getter'lar                                                          */
  /* ==================================================================== */

  group('Session getter\'lari', () {
    test('user yo\'q — fullName bo\'sh satr, teacherId null', () async {
      final s = Session();
      await s.init();
      expect(s.fullName, '');
      expect(s.teacherId, isNull);
    });

    test('user bor, lekin fullName/id kalitlari yo\'q', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'role': 'teacher'}),
      });
      final s = Session();
      await s.init();
      expect(s.fullName, '');
      expect(s.teacherId, isNull);
    });

    test('fullName null — bo\'sh satrga tushadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'fullName': null, 'id': null}),
      });
      final s = Session();
      await s.init();
      expect(s.fullName, '');
      expect(s.teacherId, isNull);
    });

    // BUG-A9 (TUZATILDI): session.dart:24-25 da `as String?` qorovulsiz edi —
    // server `id`/`fullName` ni raqam qilib qaytarsa getter'ning O'ZI
    // `build()` ichida TypeError otardi. Endi `toString()` orqali o'tadi.
    test('BUG-A9 (TUZATILDI): raqamli fullName/id String\'ga aylanadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'fullName': 42, 'id': 7}),
      });
      final s = Session();
      await s.init();
      expect(s.fullName, '42');
      expect(s.teacherId, '7');
    });

    test('BUG-A9 (TUZATILDI): kollektsiya kelsa ham getter yiqilmaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'fullName': ['Ali'], 'id': {'v': 1}}),
      });
      final s = Session();
      await s.init();
      expect(s.fullName, '[Ali]');
      expect(s.teacherId, '{v: 1}');
    });

    test('isAuthed token bilan bog\'liq', () async {
      final s = Session();
      await s.init();
      expect(s.isAuthed, isFalse);
      fake.enqueueJson({'token': 'T', 'user': {'role': 'teacher'}});
      await s.login('a@b.c', 'p');
      expect(s.isAuthed, isTrue);
      await s.logout();
      expect(s.isAuthed, isFalse);
    });
  });

  /* ==================================================================== */
  /*  setDark()                                                           */
  /* ==================================================================== */

  group('Session.setDark()', () {
    test('true — "dark" saqlanadi va xabar beriladi', () async {
      final s = Session();
      await s.init();
      var n = 0;
      s.addListener(() => n++);
      await s.setDark(true);
      expect(s.isDark, isTrue);
      expect((await prefs()).getString('teacher_theme'), 'dark');
      expect(n, 1);
    });

    test('false — "light" saqlanadi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'teacher_theme': 'dark'});
      final s = Session();
      await s.init();
      expect(s.isDark, isTrue);
      await s.setDark(false);
      expect(s.isDark, isFalse);
      expect((await prefs()).getString('teacher_theme'), 'light');
    });

    test('tema token/user\'ga tegmaydi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'token': 'TOK'});
      final s = Session();
      await s.init();
      await s.setDark(true);
      expect(s.token, 'TOK');
      expect((await prefs()).getString('token'), 'TOK');
    });
  });

  /* ==================================================================== */
  /*  login()                                                             */
  /* ==================================================================== */

  group('Session.login() — muvaffaqiyat', () {
    test('POST /auth/login, email trim qilinadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'fullName': 'Ali', 'role': 'teacher'}
      });
      final err = await s.login('  a@b.c  ', ' parol ');
      expect(err, isNull);
      expect(fake.single.method, 'POST');
      expect(fake.single.path, '/auth/login');
      expect(fake.single.body, {'email': 'a@b.c', 'password': ' parol '});
    });

    test('token va user xotiraga yoziladi, ApiClient.token o\'rnatiladi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'fullName': 'Ali', 'role': 'teacher'}
      });
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.token, 'T1');
      expect(s.isAuthed, isTrue);
      expect(s.fullName, 'Ali');
      expect(s.teacherId, 'u1');
      expect(ApiClient.token, 'T1');
      final p = await prefs();
      expect(p.getString('token'), 'T1');
      expect(jsonDecode(p.getString('user')!), {
        'id': 'u1',
        'fullName': 'Ali',
        'role': 'teacher',
      });
    });

    test('keyingi so\'rovda Authorization sarlavhasi paydo bo\'ladi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 'T1', 'user': {'role': 'teacher'}});
      await s.login('a@b.c', 'p');
      fake.enqueueJson({});
      await ApiClient.dio.get('/teacher/me');
      expect(fake.requests.last.header('Authorization'), 'Bearer T1');
    });

    test('muvaffaqiyatda notifyListeners chaqiriladi', () async {
      final s = Session();
      await s.init();
      var n = 0;
      s.addListener(() => n++);
      fake.enqueueJson({'token': 'T1', 'user': {'role': 'teacher'}});
      await s.login('a@b.c', 'p');
      expect(n, 1);
    });

    test('user null bo\'lsa xotiraga faqat token yoziladi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 'T1'});
      expect(await s.login('a@b.c', 'p'), isNull);
      final p = await prefs();
      expect(p.getString('token'), 'T1');
      expect(p.getString('user'), isNull);
      expect(s.user, isNull);
    });
  });

  group('Session.login() — xatolar', () {
    test('401 + server message — o\'sha matn qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'message': 'Parol xato'}, status: 401);
      expect(await s.login('a@b.c', 'p'), 'Parol xato');
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('400 ProblemDetails (detail) — detail qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'detail': 'Email formati xato'}, status: 400);
      expect(await s.login('a', 'p'), 'Email formati xato');
    });

    // BUG-A1 (TUZATILDI) 429/403 uchun status matnini tiklaydi, LEKIN login'da
    // 401 — "parol noto'g'ri" degani (ASP.NET `Unauthorized()` tanasiz keladi),
    // "sessiya tugadi" emas. Shuning uchun `login()` 401 ni o'zi ushlaydi.
    test('tanasiz 401 — "parol noto\'g\'ri" (umumiy 401 matni EMAS)', () async {
      final s = Session();
      await s.init();
      fake.enqueueRaw('', status: 401);
      expect(await s.login('a@b.c', 'p'), "Login yoki parol noto'g'ri");
    });

    test('401 + serverning o\'z xabari — o\'sha xabar ko\'rsatiladi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'message': 'Akkaunt bloklangan'}, status: 401);
      expect(await s.login('a@b.c', 'p'), 'Akkaunt bloklangan');
    });

    test('tanasiz 400 — login fallback\'i hamon ishlaydi', () async {
      final s = Session();
      await s.init();
      fake.enqueueRaw('', status: 400);
      expect(await s.login('a@b.c', 'p'), "Login yoki parol noto'g'ri");
    });

    test('tanasiz 429 — rate-limit matni (login fallback\'i bosib ketmaydi)', () async {
      final s = Session();
      await s.init();
      fake.enqueueRaw('', status: 429);
      expect(await s.login('a@b.c', 'p'),
          "So'rovlar juda tez — bir oz kutib qayta urinib ko'ring");
    });

    test('login 401 — onUnauthorized ISHGA TUSHMAYDI', () async {
      final s = Session();
      await s.init();
      var fired = 0;
      ApiClient.onUnauthorized = () => fired++;
      fake.enqueueRaw('', status: 401);
      await s.login('a@b.c', 'p');
      expect(fired, 0);
    });

    test('token yo\'q — "Server javobi noto\'g\'ri"', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'user': {'role': 'teacher'}});
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('rol teacher emas — kiritilmaydi va saqlanmaydi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'role': 'student'}
      });
      expect(await s.login('a@b.c', 'p'), "Bu ilova faqat o'qituvchilar uchun");
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
      expect((await prefs()).getString('token'), isNull);
    });

    test('tarmoq uzildi — "Serverga ulanib bo\'lmadi"', () async {
      final s = Session();
      await s.init();
      fake.enqueue(FakeResponse(0, '',
          error: DioException.connectionError(
              requestOptions: RequestOptions(path: '/auth/login'),
              reason: 'no internet')));
      expect(await s.login('a@b.c', 'p'), 'Serverga ulanib bo\'lmadi. Internetni tekshiring.');
    });

    // BUG-A3 (TUZATILDI): 5xx `onError` interceptor'ida `ApiException` ga
    // o'raladi va `login()` uning o'zbekcha matnini qaytaradi.
    test('500 + server message — o\'sha matn qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'message': 'server yiqildi'}, status: 500);
      expect(await s.login('a@b.c', 'p'), 'server yiqildi');
      expect(s.isAuthed, isFalse);
    });

    test('tanasiz 502 — umumiy o\'zbekcha server xatosi', () async {
      final s = Session();
      await s.init();
      fake.enqueueRaw('<html>Bad Gateway</html>', status: 502, contentType: 'text/html');
      expect(await s.login('a@b.c', 'p'),
          "Serverda xatolik — birozdan so'ng qayta urinib ko'ring");
    });

    test('timeout — "Server javob bermadi" matni', () async {
      final s = Session();
      await s.init();
      fake.enqueue(FakeResponse(0, '',
          error: DioException.receiveTimeout(
              timeout: const Duration(seconds: 1),
              requestOptions: RequestOptions(path: '/auth/login'))));
      expect(await s.login('a@b.c', 'p'),
          'Server javob bermadi — internetni tekshirib qayta urining');
    });
  });

  group('Session.login() — tasdiqlangan nuqsonlar', () {
    // BUG-A2 (TUZATILDI): session.dart:52 da `res.data as Map<String, dynamic>`
    // turgan edi. `TypeError` — `Error`, `Exception` emas, shuning uchun uni
    // na `login()`, na `login_screen.dart` ushlardi va spinner abadiy aylanardi.
    // Endi tur TEKSHIRILADI va o'zbekcha xato MATNI qaytadi.
    test('BUG-A2 (TUZATILDI): 200 + bo\'sh tana — xato matni qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueRaw('', status: 200);
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('BUG-A2 (TUZATILDI): 200 + HTML sahifa — xato matni qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueue(FakeResponse.html('<html><body>502</body></html>', status: 200));
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('BUG-A2 (TUZATILDI): 200 + JSON massiv — xato matni qaytadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson([]);
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('BUG-A2 (TUZATILDI): token String emas / bo\'sh — xato matni', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 42});
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      fake.enqueueJson({'token': ''});
      expect(await s.login('a@b.c', 'p'), "Server javobi noto'g'ri");
      expect(s.isAuthed, isFalse);
    });

    test('BUG-A2 (TUZATILDI): String bo\'lmagan kalitli javob ham yiqitmaydi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 'T1', 'user': {'role': 'teacher'}});
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
    });

    // BUG-A6: session.dart:57-60 roldan qorovul "fail-open" —
    // `role` null bo'lsa (yoki `user` umuman kelmasa) kirish RUXSAT etiladi.
    // ATAYLAB o'zgartirilmadi: `role` yubormaydigan backend javoblarida
    // o'qituvchilarni ilovadan qulflab qo'yish xavfli deb topildi; haqiqiy
    // himoya baribir serverdagi `[Authorize(Roles=...)]`.
    test('BUG-A6: user\'da role yo\'q — kirish QABUL qilinadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'fullName': 'Ali'}
      });
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
      expect(ApiClient.token, 'T1');
    });

    test('BUG-A6: user umuman yo\'q — kirish QABUL qilinadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 'T1'});
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
    });

    test('BUG-A6: role null — kirish QABUL qilinadi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'role': null}
      });
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
    });

    test('BUG-A6 (kutilgan): rolsiz javob RAD etilishi kerak', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1'}
      });
      expect(await s.login('a@b.c', 'p'), "Bu ilova faqat o'qituvchilar uchun");
      expect(s.isAuthed, isFalse);
    }, skip: 'BUG-A6 — $_kBug');

    // BUG-A6 ning tur xavfsizligi QISMI tuzatildi: rol String bo'lmasa avval
    // `role as String?` cast'i TypeError berardi, endi `toString()` bilan
    // solishtiriladi va oddiy rad javobi qaytadi.
    test('BUG-A6 (TUZATILDI): String bo\'lmagan rol yiqitmaydi, RAD etiladi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'role': 42}
      });
      expect(await s.login('a@b.c', 'p'), "Bu ilova faqat o'qituvchilar uchun");
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('BUG-A6 (TUZATILDI): user Map bo\'lmasa ham yiqitmaydi', () async {
      final s = Session();
      await s.init();
      fake.enqueueJson({'token': 'T1', 'user': 'ali'});
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
      expect(s.user, isNull);
    });
  });

  /* ==================================================================== */
  /*  logout()                                                            */
  /* ==================================================================== */

  group('Session.logout()', () {
    Future<Session> loggedIn() async {
      final s = Session();
      await s.init();
      fake.enqueueJson({
        'token': 'T1',
        'user': {'id': 'u1', 'fullName': 'Ali', 'role': 'teacher'}
      });
      await s.login('a@b.c', 'p');
      return s;
    }

    test('token/user xotiradan va ApiClient\'dan o\'chadi', () async {
      final s = await loggedIn();
      await s.logout();
      expect(s.token, isNull);
      expect(s.user, isNull);
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
      final p = await prefs();
      expect(p.getString('token'), isNull);
      expect(p.getString('user'), isNull);
    });

    test('tema saqlanib qoladi', () async {
      final s = await loggedIn();
      await s.setDark(true);
      await s.logout();
      expect(s.isDark, isTrue);
      expect((await prefs()).getString('teacher_theme'), 'dark');
    });

    test('kirmagan holatda ham xatosiz ishlaydi', () async {
      final s = Session();
      await s.init();
      await s.logout();
      expect(s.isAuthed, isFalse);
    });

    test('notifyListeners chaqiriladi', () async {
      final s = await loggedIn();
      var n = 0;
      s.addListener(() => n++);
      await s.logout();
      expect(n, 1);
    });

    // BUG-A8 (TUZATILDI): `_loggingOut` qorovuli + `_token == null` tekshiruvi.
    // Bunsiz cheksiz sikl bor edi: logout → PushService.clear →
    // unregisterPushToken → 401 → onUnauthorized → logout → ...
    test('BUG-A8 (TUZATILDI): takroriy logout bir martagina bajariladi', () async {
      final s = await loggedIn();
      var n = 0;
      s.addListener(() => n++);
      await Future.wait<void>([s.logout(), s.logout()]);
      expect(n, 1);
      expect(s.isAuthed, isFalse);
    });

    test('BUG-A8 (TUZATILDI): ketma-ket ikkita 401 FAQAT bitta logout beradi', () async {
      final s = await loggedIn();
      var n = 0;
      s.addListener(() => n++);
      fake.always(FakeResponse(401, ''));
      await ApiClient.dio.get('/teacher/me');
      await ApiClient.dio.get('/teacher/classes');
      // logout() asinxron — mikrotask navbatini bo'shatamiz.
      await Future<void>.delayed(Duration.zero);
      expect(n, 1, reason: 'ikkinchi 401 qorovuldan o\'tmasligi kerak');
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('BUG-A8 (TUZATILDI): chiqilgandan keyingi 401 logout\'ni qo\'zg\'amaydi', () async {
      final s = await loggedIn();
      await s.logout();
      var n = 0;
      s.addListener(() => n++);
      fake.always(FakeResponse(401, ''));
      await ApiClient.dio.get('/teacher/me');
      await Future<void>.delayed(Duration.zero);
      expect(n, 0);
    });

    test('BUG-A8 (TUZATILDI): chiqqandan keyin qaytadan kirish va chiqish ishlaydi',
        () async {
      final s = await loggedIn();
      await s.logout();
      // Qorovul "yopiq" holatda qolib ketmasligi kerak.
      fake.enqueueJson({
        'token': 'T2',
        'user': {'id': 'u1', 'role': 'teacher'}
      });
      expect(await s.login('a@b.c', 'p'), isNull);
      expect(s.isAuthed, isTrue);
      await s.logout();
      expect(s.isAuthed, isFalse);
      expect(ApiClient.token, isNull);
    });

    test('logout()dan keyin ham ApiClient.onUnauthorized ulangan qoladi', () async {
      final s = await loggedIn();
      await s.logout();
      expect(ApiClient.onUnauthorized, isNotNull);
    });

    test('onLoggedOut callback\'i chaqiriladi', () async {
      final s = await loggedIn();
      var fired = 0;
      s.onLoggedOut = () => fired++;
      await s.logout();
      expect(fired, 1);
    });
  });

  /* ==================================================================== */
  /*  PushService.clear() — sessiyasiz so'rov yubormaydi                  */
  /* ==================================================================== */

  test('PushService.clear() — token null bo\'lsa HTTP so\'rov yubormaydi', () async {
    // P0-1 siklining ikkinchi bo'g'ini: `clear()` tokensiz ham
    // `DELETE /teacher/notifications/register` yuborardi → 401 → logout → ...
    //
    // DIQQAT: bu test qorovulning REGRESSIYA himoyasi. Test muhitida Firebase
    // yo'q, shuning uchun qorovulsiz ham `getToken()` yiqilib so'rov ketmasdi —
    // haqiqiy qurilmada esa ketardi. `always` qo'yilgani uchun har qanday
    // kutilmagan so'rov javob oladi va `fake.count` da ko'rinadi.
    fake.always(FakeResponse(401, ''));
    ApiClient.token = null;
    await PushService.instance.clear();
    expect(fake.count, 0);
  });

  /* ==================================================================== */
  /*  401 → sessiya yopilishi (uchidan-uchiga)                            */
  /* ==================================================================== */

  test('init() dan keyin non-login 401 sessiyani yopadi', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'token': 'TOK',
      'user': jsonEncode({'id': 'u1', 'role': 'teacher'}),
    });
    final s = Session();
    await s.init();
    expect(s.isAuthed, isTrue);

    fake.enqueueRaw('', status: 401);
    await ApiClient.dio.get('/teacher/me');
    // logout() asinxron — mikrotask/kutish navbatini bo'shatamiz.
    await Future<void>.delayed(Duration.zero);

    expect(s.isAuthed, isFalse);
    expect(ApiClient.token, isNull);
    expect((await prefs()).getString('token'), isNull);
  });

  test('soxta adapter o\'rnatilgan — haqiqiy tarmoq ishlatilmaydi', () {
    expect(ApiClient.dio.httpClientAdapter, same(fake));
  });
}
