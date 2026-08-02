import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'push.dart';

/// O'qituvchi sessiyasi + tema. Ilovaning tepasida `ChangeNotifierProvider` bilan beriladi.
class Session extends ChangeNotifier {
  static const _kToken = 'token';
  static const _kUser = 'user';
  static const _kTheme = 'teacher_theme';

  String? _token;
  Map<String, dynamic>? _user;
  bool _dark = false;
  bool _ready = false;

  /// Chiqish jarayoni ketayaptimi — 401 kelganda qayta-qayta `logout()` ni
  /// qo'zg'atmaslik uchun (aks holda cheksiz sikl hosil bo'ladi, pastga qarang).
  bool _loggingOut = false;

  /// Chiqilganda chaqiriladi — `main.dart` buni Navigator'ni ildizga
  /// qaytarishga ulaydi. Bunsiz 401 kelganda `MaterialApp.home` LoginScreen'ga
  /// o'tardi-yu, ochilgan sub-ekran (Maosh, Shartnomalar) stack tepasida
  /// qolaverardi va o'lik sessiyada ishlayotgandek ko'rinardi.
  VoidCallback? onLoggedOut;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthed => _token != null;
  bool get isDark => _dark;
  bool get ready => _ready;

  /// DIQQAT: qiymat serverdan/`SharedPreferences`dan kelgani uchun turi
  /// kafolatlanmaydi. Xom `as String?` cast'i raqamli `fullName`/`id` kelganda
  /// `build()` ichida `TypeError` berib ekranni yiqitardi.
  String get fullName {
    final v = _user?['fullName'];
    return v == null ? '' : v.toString();
  }

  String? get teacherId {
    final v = _user?['id'];
    return v == null ? null : v.toString();
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString(_kToken);
    final u = p.getString(_kUser);
    if (u != null) {
      try {
        _user = _asUser(jsonDecode(u));
      } catch (_) {}
    }
    _dark = p.getString(_kTheme) == 'dark';
    ApiClient.token = _token;
    ApiClient.onUnauthorized = _onUnauthorized;
    _ready = true;
    notifyListeners();
  }

  /// Kalitlari String bo'lgan map — `jsonDecode` odatda shuni beradi, lekin
  /// buzuq saqlangan qiymat butun kirishni yiqitmasligi kerak.
  static Map<String, dynamic>? _asUser(dynamic v) {
    if (v is! Map) return null;
    final out = <String, dynamic>{};
    v.forEach((k, val) => out[k.toString()] = val);
    return out;
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await ApiClient.dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });
      if (!ApiClient.ok(res)) {
        // DIQQAT: `/auth/login` da 401 "sessiya tugadi" EMAS — ASP.NET
        // `Unauthorized()` ni tanasiz qaytaradi va bu "parol noto'g'ri"
        // degani. Shuning uchun bu yerda `errorMessage`ning umumiy 401
        // matnini ishlatmaymiz (429/403 uchun esa u to'g'ri matn beradi).
        if (res.statusCode == 401) {
          final d = res.data;
          final serverMsg = d is Map && d['message'] is String ? d['message'] as String : null;
          return serverMsg ?? "Login yoki parol noto'g'ri";
        }
        return ApiClient.errorMessage(res, "Login yoki parol noto'g'ri");
      }
      // DIQQAT: bu yerda xom `as Map<String, dynamic>` cast'i turgan edi.
      // `TypeError` — `Exception` emas, `Error`, shuning uchun uni quyidagi
      // `catch` ham, `login_screen.dart` dagi chaqiruvchi ham tutmasdi:
      // spinner abadiy aylanardi. Endi tur tekshirib ko'riladi.
      // 200 bo'lsa ham tana bo'sh (`''`/`null`) yoki HTML bo'lishi mumkin.
      final data = res.data;
      if (data is! Map) return "Server javobi noto'g'ri";
      final token = data['token'];
      if (token is! String || token.isEmpty) return "Server javobi noto'g'ri";
      final user = _asUser(data['user']);
      // Faqat o'qituvchi rolini bu ilovaga kiritamiz.
      // Rol umuman kelmasa kiritamiz (ba'zi backend javoblarida `role` yo'q) —
      // haqiqiy himoya baribir serverdagi `[Authorize(Roles=...)]`.
      final role = user?['role'];
      if (role != null && role.toString() != 'teacher') {
        return "Bu ilova faqat o'qituvchilar uchun";
      }
      await _persist(token, user);
      return null; // muvaffaqiyat
    } on ApiException catch (e) {
      // 5xx/timeout/tarmoq — `api_client.dart` allaqachon o'zbekcha matn beradi.
      return e.message;
    } catch (_) {
      return "Serverga ulanib bo'lmadi. Internetni tekshiring.";
    }
  }

  /// Avval DISKKA yoziladi, keyin xotira holati o'zgaradi: yozuv yiqilsa ilova
  /// "xotirada kirgan, lekin login ekranida" degan chalkash holatda qolmaydi.
  Future<void> _persist(String token, Map<String, dynamic>? user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    if (user != null) {
      try {
        await p.setString(_kUser, jsonEncode(user));
      } catch (_) {
        await p.remove(_kUser); // kodlanmaydigan qiymat — user'siz davom etamiz
      }
    } else {
      await p.remove(_kUser);
    }
    _token = token;
    _user = user;
    ApiClient.token = token;
    _loggingOut = false;
    notifyListeners();
    // Kirgach FCM token'ni backend'ga yuboramiz. KUTILMAYDI va xatosi
    // login natijasiga ta'sir qilmaydi — aks holda Firebase ishlamagan
    // qurilmada muvaffaqiyatli login "Serverga ulanib bo'lmadi" bo'lib ko'rinardi.
    try {
      PushService.instance.syncToken();
    } catch (_) {}
  }

  /// 401 kelganda chaqiriladi.
  ///
  /// QOROVUL: bunsiz cheksiz sikl bor edi — `logout()` → `PushService.clear()`
  /// → tokensiz `DELETE /notifications/register` → 401 → yana `logout()`...
  /// Sikl ishlaganda login muvaffaqiyatli bo'lsa ham foydalanuvchi darhol
  /// chiqarib yuborilardi va ilovani yopmaguncha kira olmasdi.
  void _onUnauthorized() {
    if (_token == null || _loggingOut) return;
    logout();
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    // 1) UI darhol login ekraniga qaytsin — tarmoqni kutmaydi.
    _token = null;
    _user = null;
    notifyListeners();
    onLoggedOut?.call();
    // DIQQAT: qolgan hamma narsa `finally` bilan himoyalangan. Bunsiz
    // `SharedPreferences` bitta `PlatformException` bersa `_loggingOut`
    // ABADIY `true` bo'lib qolardi — ya'ni `_onUnauthorized` butunlay
    // o'chib, ilova 401 ga umuman javob bermay qo'yardi, `ApiClient.token`
    // esa o'lik token bilan qolib ketardi.
    try {
      // 2) Saqlangan sessiyani o'chiramiz.
      final p = await SharedPreferences.getInstance();
      await p.remove(_kToken);
      await p.remove(_kUser);
    } catch (_) {
      // Diskka yozib bo'lmadi — xotira holati baribir tozalangan.
    } finally {
      // 3) Push token'ni backend'dan o'chiramiz. `ApiClient.token` ATAYLAB
      //    hali tozalanmagan: DELETE so'rovi `Authorization` bilan ketishi
      //    kerak. Kutish 5 soniya bilan chegaralangan (avval 20+30 s
      //    timeout'da UI hech qanday indikatorsiz muzlab qolardi).
      try {
        await PushService.instance.clear().timeout(const Duration(seconds: 5));
      } catch (_) {}
      ApiClient.token = null;
      _loggingOut = false;
    }
  }

  Future<void> setDark(bool v) async {
    _dark = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, v ? 'dark' : 'light');
    notifyListeners();
  }
}
