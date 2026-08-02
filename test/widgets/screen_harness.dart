// Ekran (widget/integration) testlari uchun umumiy harness.
//
// Maqsad: butun EKRANlarni haqiqiy `State` mantiqi bilan, lekin SOXTA HTTP
// transporti ustida haydab, hozirgi xulqni "qulflab" qo'yish.
//
// DIQQAT: bu fayl faqat shu paket ichida ishlatiladi (`test/widgets/*`).
// `test/helpers/fake_api.dart` BOSHQA agentniki — bu yerda ishlatilmaydi.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacher/api/api_client.dart';
import 'package:teacher/services/session.dart';
import 'package:teacher/theme/app_theme.dart';

/* ---------------------------------------------------------------- *
 *  Soxta HTTP transport
 * ---------------------------------------------------------------- */

/// Bitta soxta javob: status + JSON tanasi (+ ixtiyoriy "eshik" — javobni
/// test o'zi xohlagan paytda qo'yib yuborishi uchun).
class FakeRoute {
  const FakeRoute({this.status = 200, this.body, this.gate});

  final int status;
  final Object? body;

  /// To'ldirilmaguncha javob qaytmaydi (masalan "so'rov ketayotganda tugma
  /// o'chganmi?" degan testlar uchun).
  final Completer<void>? gate;
}

/// Fake adapter yozib olgan bitta so'rov.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.uri,
    required this.data,
  });

  final String method;
  final String path;
  final Uri uri;
  final Object? data;

  @override
  String toString() => '$method $uri';
}

/// `ApiClient.dio` ning transportini almashtiradigan soxta adapter.
///
/// Yo'l (`route`) kaliti — `options.path` ichida QIDIRILADIGAN parcha
/// (masalan `/teacher/journal/group`). Birinchi mos kelgani ishlaydi, shuning
/// uchun aniqrog'ini oldin qo'shing.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([Map<String, FakeRoute>? initial]) {
    if (initial != null) routes.addAll(initial);
  }

  final Map<String, FakeRoute> routes = <String, FakeRoute>{};

  /// Yozib olingan barcha so'rovlar (tartibi bilan).
  final List<RecordedRequest> requests = <RecordedRequest>[];

  /// Hech qaysi yo'lga mos kelmagan so'rovlar — testda "kutilmagan chaqiruv"
  /// borligini ko'rsatadi.
  final List<String> unmatched = <String>[];

  void on(String pattern, {int status = 200, Object? body, Completer<void>? gate}) {
    routes[pattern] = FakeRoute(status: status, body: body, gate: gate);
  }

  /// Shu parchani o'z ichiga olgan so'rovlar soni.
  int countOf(String pattern) =>
      requests.where((r) => r.path.contains(pattern)).length;

  RecordedRequest? lastOf(String pattern) {
    for (final r in requests.reversed) {
      if (r.path.contains(pattern)) return r;
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(RecordedRequest(
      method: options.method,
      path: options.path,
      uri: options.uri,
      data: options.data,
    ));

    FakeRoute? route;
    for (final e in routes.entries) {
      if (options.path.contains(e.key)) {
        route = e.value;
        break;
      }
    }
    if (route == null) {
      unmatched.add('${options.method} ${options.path}');
      route = const FakeRoute(
        status: 404,
        body: <String, Object?>{'message': 'FakeAdapter: yo\'l ro\'yxatda yo\'q'},
      );
    }
    if (route.gate != null) await route.gate!.future;

    return ResponseBody.fromString(
      jsonEncode(route.body ?? const <String, Object?>{}),
      route.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/* ---------------------------------------------------------------- *
 *  Asset bundle (logo) — `--no-test-assets` bilan ham ishlashi uchun
 * ---------------------------------------------------------------- */

/// 1×1 shaffof PNG — `AssetImage` dekod qila oladigan eng kichik rasm.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// Har qanday asset kalitiga kichik PNG qaytaradi (login ekranidagi
/// `assets/logo.jpg` testda mavjud bo'lmagani uchun rasm yuklash xatosi
/// testni yiqitmasin).
class _StubAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin' || key == 'AssetManifest.bin.json') {
      return const StandardMessageCodec().encodeMessage(<String, Object?>{})!;
    }
    if (key == 'AssetManifest.json' || key == 'FontManifest.json') {
      final bytes = utf8.encode(key.startsWith('Font') ? '[]' : '{}');
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }
    return ByteData.view(_tinyPng.buffer);
  }
}

/* ---------------------------------------------------------------- *
 *  Test qobig'i
 * ---------------------------------------------------------------- */

/// Har testdan oldin: SharedPreferences mock, `ApiClient` global holatini
/// tozalash va transportni soxtasiga almashtirish.
FakeAdapter installFakeApi([Map<String, FakeRoute>? routes]) {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  ApiClient.token = null;
  ApiClient.onUnauthorized = null;
  final adapter = FakeAdapter(routes);
  ApiClient.dio.httpClientAdapter = adapter;
  return adapter;
}

/// Ekranni `MaterialApp` + `AppTheme` + `Session` (provider) ichida ochadi.
///
/// DIQQAT (o'lcham): guruh jurnali/baholash jadvali KENG — telefon o'lchamida
/// test mavzusiga aloqasi yo'q "RenderFlex overflowed" shovqini chiqadi.
/// Shuning uchun ko'rinish sun'iy ravishda 1400×2400 (dpr 1.0) qilib
/// kengaytiriladi va test oxirida `tester.view.reset()` bilan qaytariladi.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(1400, 2400),
  bool dark = false,
  Session? session,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final colors = dark ? AppColors.dark : AppColors.light;
  final s = session ?? Session();

  await tester.pumpWidget(
    ChangeNotifierProvider<Session>.value(
      value: s,
      child: DefaultAssetBundle(
        bundle: _StubAssetBundle(),
        child: AppTheme(
          colors: colors,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildMaterialTheme(colors),
            home: screen,
          ),
        ),
      ),
    ),
  );
}

/// Matnning ekrandagi vertikal o'rni — qatorlar TARTIBINI tekshirish uchun.
double topOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

/// Matnning gorizontal o'rni — qaysi ustunda turganini tekshirish uchun.
double leftOf(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dx;

/// Debug rejimidagi tasodifiy `debugPrint` shovqinini o'chirish (ixtiyoriy).
void silenceDebugPrint() {
  debugPrint = (String? message, {int? wrapWidth}) {};
}
