import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// API xatosi — HTTP status kodi bilan. `toString()` faqat xabarni qaytaradi,
/// shuning uchun ekranlarda ko'rsatilayotgan matn o'zgarmaydi; status kodi esa
/// log/diagnostika uchun ochiq turadi (`e.statusCode`).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.data]);

  final int? statusCode;
  final String message;
  final Object? data;

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
        final isLogin = response.requestOptions.path.contains('/auth/login');
        if (code == 401 && !isLogin) {
          onUnauthorized?.call();
        }
        handler.next(response);
      },
    ));
    return d;
  }

  /// Javob 2xx bo'lmasa serverdagi `message`ni yoki umumiy xatoni chiqaradi.
  ///
  /// Backend xato javoblari uch xil ko'rinishda keladi:
  ///  • `{ "message": "..." }` — bizning controller'lar (BadRequest/Conflict);
  ///  • ProblemDetails (`title`/`detail`) — ASP.NET model validatsiyasi (400);
  ///  • BO'SH tana — `Unauthorized()`/`Forbid()` (401/403), 404, 429.
  /// Oxirgi holatda status kodiga qarab tushunarli matn beramiz — aks holda
  /// hamma narsa "Xatolik yuz berdi" bo'lib, sababi bilinmay qoladi.
  static String errorMessage(Response? res, [Object? fallback]) {
    final data = res?.data;
    if (data is Map) {
      if (data['message'] is String) return data['message'] as String;
      if (data['detail'] is String) return data['detail'] as String;
      if (data['title'] is String) return data['title'] as String;
    }
    if (fallback != null) return fallback.toString();
    switch (res?.statusCode) {
      case 401:
        return "Sessiya muddati tugadi — qaytadan kiring";
      case 403:
        return "Bu amal uchun ruxsat yo'q";
      case 404:
        return "Ma'lumot topilmadi";
      case 429:
        return "So'rovlar juda tez — bir oz kutib qayta urinib ko'ring";
      default:
        return 'Xatolik yuz berdi';
    }
  }

  static bool ok(Response res) {
    final c = res.statusCode ?? 0;
    return c >= 200 && c < 300;
  }
}
