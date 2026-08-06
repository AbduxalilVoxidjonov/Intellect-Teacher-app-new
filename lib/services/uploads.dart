import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../config.dart';

/// YUKLANGAN FAYLLAR (`/uploads/...`) BILAN ISHLASHNING YAGONA JOYI.
///
/// NEGA KERAK (backend commit `52eda96`, `.claude/rules/uploads-security.md`):
/// `/uploads` endi autentifikatsiyasiz **404** qaytaradi. Brauzer uchun server
/// `Path=/uploads` ga cheklangan `up_at` cookie'sini qo'yadi, LEKIN Flutter
/// ilovasida cookie yo'q — shuning uchun har bir so'rovga
/// `Authorization: Bearer <token>` sarlavhasi QO'LDA qo'shilishi shart.
///
/// ⚠️ TASHQI BRAUZER ISHLAMAYDI: `url_launcher` bilan `/uploads/...` manzilini
/// ochish endi mumkin emas — tizim brauzerida na token, na cookie bor va
/// foydalanuvchi 404 ko'radi. Shuning uchun fayl AVVAL ilova ichida (token
/// bilan) yuklab olinadi, keyin vaqtinchalik faylga yozilib qurilmaning o'z
/// ilovasida ochiladi (`OpenFilex`).
class Uploads {
  Uploads._();

  /// Nisbiy fayl manzilini baza URL ustiga TO'G'RI ulaydi.
  ///
  /// Server "uploads/x.pdf" (boshida "/" siz) qaytarsa oddiy satr qo'shish
  /// "https://hostuploads/x.pdf" hosil qilardi — shuning uchun `Uri.resolve`.
  static Uri? resolve(String url) {
    final t = url.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http')) return Uri.tryParse(t);
    final base = Uri.tryParse(kFileBaseUrl);
    if (base == null) return null;
    try {
      return base.resolve(t);
    } catch (_) {
      return null;
    }
  }

  /// `/uploads` darvozasi kutayotgan sarlavha. Token yo'q bo'lsa (chiqib
  /// ketilgan) — bo'sh map: so'rov baribir 404 bo'ladi, lekin `null` satr
  /// sarlavhaga yozilib ketmaydi.
  static Map<String, String> authHeaders() {
    final t = ApiClient.token;
    return (t == null || t.isEmpty)
        ? const <String, String>{}
        : <String, String>{'Authorization': 'Bearer $t'};
  }

  /// Rasm manbai — `Image(image: ...)` uchun. Manzil bo'sh/buzuq bo'lsa `null`
  /// (chaqiruvchi bosh harflar kabi zaxira ko'rinishni chizadi).
  ///
  /// DIQQAT: sarlavhasiz `Image.network` deploydan keyin BARCHA rasmni
  /// yo'qotardi — shuning uchun ilovada rasm faqat shu funksiya orqali olinadi.
  static ImageProvider? image(String url) {
    final uri = resolve(url);
    if (uri == null) return null;
    return NetworkImage(uri.toString(), headers: authHeaders());
  }

  /// Faylni token bilan yuklab oladi (baytlar). Xato bo'lsa `ApiException`.
  static Future<Uint8List> bytes(String url) async {
    final uri = resolve(url);
    if (uri == null) throw ApiException(null, "Fayl manzili noto'g'ri");
    final res = await ApiClient.dio.get<List<int>>(
      uri.toString(),
      // Token'ni `ApiClient` interceptor'i qo'shadi — `authHeaders()` bilan
      // AYNI manba, ya'ni ikki joyda ayri ketmaydi.
      options: Options(responseType: ResponseType.bytes),
    );
    if (!ApiClient.ok(res)) {
      throw ApiException(res.statusCode, ApiClient.errorMessage(res, "Faylni yuklab bo'lmadi"));
    }
    final data = res.data;
    if (data == null || data.isEmpty) throw ApiException(null, "Fayl bo'sh");
    return Uint8List.fromList(data);
  }

  /// Fayl nomini manzildan ajratib oladi (kengaytmasi bilan) — vaqtinchalik
  /// faylga o'sha kengaytma bilan yozilmasa qurilma uni qaysi ilovada
  /// ochishni bilmaydi.
  static String fileNameOf(String url, {String fallback = 'fayl'}) {
    final uri = resolve(url);
    final segs = uri?.pathSegments ?? const <String>[];
    for (final s in segs.reversed) {
      if (s.trim().isNotEmpty) return s;
    }
    return fallback;
  }

  /// Faylni yuklab olib qurilmaning o'z ilovasida ochadi.
  ///
  /// Qaytadi: `null` — muvaffaqiyat, aks holda foydalanuvchiga ko'rsatiladigan
  /// xato matni (chaqiruvchi uni toast qilib chiqaradi).
  static Future<String?> openExternally(String url) async {
    late final Uint8List data;
    try {
      data = await bytes(url);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return "Faylni yuklab bo'lmadi";
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${fileNameOf(url)}');
      await file.writeAsBytes(data, flush: true);
      final r = await OpenFilex.open(file.path);
      if (r.type != ResultType.done) return "Faylni ochib bo'lmadi";
      return null;
    } catch (_) {
      return "Faylni ochib bo'lmadi";
    }
  }
}
