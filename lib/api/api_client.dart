import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// API xatosi — HTTP status kodi bilan. `toString()` faqat xabarni qaytaradi,
/// shuning uchun ekranlarda ko'rsatilayotgan matn o'zgarmaydi; status kodi esa
/// log/diagnostika uchun ochiq turadi (`e.statusCode`).
///
/// `DioException` dan meros olinadi: dio ichidagi barcha xatolar oxirida
/// `DioException` ga o'raladi (`assureDioException`), shuning uchun `onError`
/// interceptor'i xatoni `ApiException` ko'rinishida RAD ETA olishi va shu
/// obyekt o'zgarishsiz chaqiruvchiga (ekranlarga) yetib borishi uchun.
/// Ekranlar `e.toString()` ni to'g'ridan-to'g'ri chiqaradi — `toString()`
/// faqat o'zbekcha matnni qaytargani uchun inglizcha dio matni ko'rinmaydi.
class ApiException extends DioException {
  ApiException(
    this.statusCode,
    String message, [
    this.data,
    RequestOptions? requestOptions,
    Response<dynamic>? response,
    DioExceptionType type = DioExceptionType.unknown,
  ]) : super(
          requestOptions: requestOptions ?? RequestOptions(path: ''),
          response: response,
          type: type,
          message: message,
        );

  final int? statusCode;
  final Object? data;

  /// Har doim bor — `DioException.message` esa `null` bo'lishi mumkin.
  @override
  String get message => super.message ?? 'Xatolik yuz berdi';

  @override
  String toString() => message;

  /// Log uchun to'liq ko'rinish: `[401] Sessiya muddati tugadi ...`.
  String get details {
    final body = data == null ? '' : ' body=$data';
    return '[${statusCode ?? '-'}] $message$body';
  }
}

/// Markaziy Dio klienti — web `client.ts` bilan bir xil mantiq:
/// har so'rovga `Bearer <token>`; 401 (login'dan tashqari) → sessiya tugadi.
class ApiClient {
  static String? token;
  static VoidCallback? onUnauthorized;

  /// 401 kelganda sessiyani YOPMAYDIGAN yo'llar.
  ///  • `/auth/login` — noto'g'ri parol sessiyani yopmasligi kerak;
  ///  • push token ro'yxati — chiqish paytida tokensiz ketishi mumkin va
  ///    uning 401'i yana `logout()` ni qo'zg'ab cheksiz siklga olib keladi.
  static bool _skipUnauthorized(String path) =>
      path.contains('/auth/login') || path.contains('/notifications/register');

  static final Dio dio = _build();

  static Dio _build() {
    final d = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // 4xx'ni ham qabul qilamiz — xatoni o'zimiz o'qiymiz.
      validateStatus: (s) => s != null && s < 500,
    ));
    d.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final code = response.statusCode ?? 0;
        if (code == 401 && !_skipUnauthorized(response.requestOptions.path)) {
          onUnauthorized?.call();
        }
        handler.next(response);
      },
      // 5xx, timeout, tarmoq uzilishi — dio'ning inglizcha `DioException`
      // matni o'rniga o'zbekcha `ApiException`. Ekranlar `e.toString()` ni
      // chiqargani uchun bu shart.
      onError: (e, handler) {
        handler.reject(_wrap(e));
      },
    ));
    return d;
  }

  /// `DioException` → `ApiException` (o'zbekcha matn bilan).
  static ApiException _wrap(DioException e) {
    if (e is ApiException) return e; // qayta o'ramaymiz
    final res = e.response;
    final code = res?.statusCode;
    final String msg;
    switch (e.type) {
      case DioExceptionType.badResponse:
        // 5xx: serverning o'z `message`i bo'lsa — o'sha, aks holda umumiy matn.
        msg = errorMessage(
          res,
          "Serverda xatolik — birozdan so'ng qayta urinib ko'ring",
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        msg = "Server javob bermadi — internetni tekshirib qayta urining";
      case DioExceptionType.connectionError:
        msg = "Serverga ulanib bo'lmadi. Internetni tekshiring.";
      case DioExceptionType.badCertificate:
        msg = "Server sertifikati noto'g'ri";
      case DioExceptionType.cancel:
        msg = "So'rov bekor qilindi";
      default:
        msg = "Xatolik yuz berdi. Qayta urinib ko'ring.";
    }
    return ApiException(code, msg, res?.data, e.requestOptions, res, e.type);
  }

  /// Javob 2xx bo'lmasa serverdagi `message`ni yoki umumiy xatoni chiqaradi.
  ///
  /// Backend xato javoblari uch xil ko'rinishda keladi:
  ///  • `{ "message": "..." }` — bizning controller'lar (BadRequest/Conflict);
  ///  • ProblemDetails (`title`/`detail`) — ASP.NET model validatsiyasi (400);
  ///  • BO'SH tana — `Unauthorized()`/`Forbid()` (401/403), 404, 429.
  /// Oxirgi holatda status kodiga qarab tushunarli matn beramiz; `fallback`
  /// esa FAQAT status kodi tanish bo'lmaganda ishlatiladi — aks holda
  /// login ekranidagi tanasiz 429 "Login yoki parol noto'g'ri" bo'lib
  /// ko'rinardi va o'qituvchi qayta-qayta urinib rate-limitni chuqurlashtirardi.
  static String errorMessage(Response? res, [Object? fallback]) {
    final data = res?.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['title'] is String) return data['title'] as String;
    }
    switch (res?.statusCode) {
      case 401:
        return "Sessiya muddati tugadi — qaytadan kiring";
      case 403:
        return "Bu amal uchun ruxsat yo'q";
      case 404:
        return "Ma'lumot topilmadi";
      case 413:
        return "Fayl juda katta";
      case 429:
        return "So'rovlar juda tez — bir oz kutib qayta urinib ko'ring";
      default:
        return fallback != null ? fallback.toString() : 'Xatolik yuz berdi';
    }
  }

  static bool ok(Response res) {
    final c = res.statusCode ?? 0;
    return c >= 200 && c < 300;
  }
}
