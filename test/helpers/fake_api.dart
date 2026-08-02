// Tarmoqqa CHIQMAYDIGAN soxta (fake) HTTP transport — `ApiClient.dio` ning
// `httpClientAdapter` i shu bilan almashtiriladi, shuning uchun testlar hech
// qachon haqiqiy serverga bormaydi.
//
// Yangi paket qo'shilmaydi: faqat `dio` ning o'z `HttpClientAdapter`
// interfeysi ishlatiladi.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adapterga yetib kelgan bitta so'rovning to'liq surati.
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.uri,
    required this.queryParameters,
    required this.headers,
    required this.data,
    required this.bodyBytes,
  });

  /// HTTP metodi — har doim BOSH HARFDA ('GET', 'POST', ...).
  final String method;

  /// `dio.get('/teacher/me')` ga berilgan xom yo'l (baseUrl'siz).
  final String path;

  /// To'liq manzil (baseUrl + path + query) — kodlashni tekshirish uchun.
  final Uri uri;

  /// `queryParameters` — `_qp` null'larni tashlaganini tekshirish uchun.
  final Map<String, dynamic> queryParameters;

  final Map<String, dynamic> headers;

  /// `dio.post(..., data: X)` dagi X — odatda `Map` yoki `FormData`.
  final Object? data;

  /// Simga chiqqan xom baytlar (JSON/multipart).
  final Uint8List bodyBytes;

  /// Sarlavhani registrga bog'liq bo'lmagan holda o'qish.
  String? header(String name) {
    final lower = name.toLowerCase();
    for (final e in headers.entries) {
      if (e.key.toLowerCase() == lower) {
        final v = e.value;
        return v is List ? v.join(', ') : v?.toString();
      }
    }
    return null;
  }

  /// So'rov tanasi `Map` bo'lsa — o'sha map.
  Map<String, dynamic> get body =>
      data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};

  /// Xom baytlardan o'qilgan JSON (transformer nima yuborganini tekshirish uchun).
  Object? get wireJson {
    if (bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String get bodyText => bodyBytes.isEmpty ? '' : utf8.decode(bodyBytes);

  /// `uri.path` da foiz-kodlash saqlanadi, `pathSegments` esa dekodlangan.
  List<String> get pathSegments => uri.pathSegments;

  @override
  String toString() => '$method ${uri.toString()}';
}

/// Adapter qaytaradigan tayyorlangan javob.
class FakeResponse {
  FakeResponse(
    this.status,
    this.body, {
    Map<String, List<String>>? headers,
    this.contentType = Headers.jsonContentType,
    this.delay,
    this.error,
  }) : extraHeaders = headers ?? const {};

  final int status;
  final String body;
  final String? contentType;
  final Map<String, List<String>> extraHeaders;
  final Duration? delay;

  /// Berilsa — javob o'rniga shu xato otiladi (tarmoq uzilishini taqlid qilish).
  final Object? error;

  /// JSON obyektidan javob yasash.
  factory FakeResponse.json(Object? data, {int status = 200}) =>
      FakeResponse(status, jsonEncode(data));

  /// Tanasiz javob (204 / bo'sh 200) — dio bunda `''` beradi.
  factory FakeResponse.empty({int status = 204}) => FakeResponse(status, '');

  /// HTML sahifa (nginx/proxy xato sahifasi).
  factory FakeResponse.html(String html, {int status = 200}) =>
      FakeResponse(status, html, contentType: 'text/html; charset=utf-8');
}

/// `dio` ning transportini to'liq almashtiradigan soxta adapter.
///
/// Ishlatish:
/// ```dart
/// final fake = FakeAdapter();
/// ApiClient.dio.httpClientAdapter = fake;
/// fake.enqueueJson({'ok': true});
/// ```
class FakeAdapter implements HttpClientAdapter {
  final List<RecordedRequest> requests = <RecordedRequest>[];
  final List<FakeResponse> _queue = <FakeResponse>[];
  FakeResponse? _always;
  bool closed = false;

  /* ---------- javob rejalashtirish ---------- */

  void enqueue(FakeResponse r) => _queue.add(r);

  void enqueueJson(Object? data, {int status = 200}) =>
      _queue.add(FakeResponse.json(data, status: status));

  /// Xom matnli javob (bo'sh tana, HTML, buzilgan JSON ...).
  void enqueueRaw(String body,
          {int status = 200, String? contentType = Headers.jsonContentType}) =>
      _queue.add(FakeResponse(status, body, contentType: contentType));

  void enqueueEmpty({int status = 204}) =>
      _queue.add(FakeResponse.empty(status: status));

  /// Navbat tugagach har doim shu javob qaytadi.
  void always(FakeResponse r) => _always = r;

  void alwaysJson(Object? data, {int status = 200}) =>
      _always = FakeResponse.json(data, status: status);

  /* ---------- yozib olingan so'rovlar ---------- */

  RecordedRequest get last => requests.last;
  RecordedRequest get single => requests.single;
  int get count => requests.length;

  void reset() {
    requests.clear();
    _queue.clear();
    _always = null;
  }

  /* ---------- HttpClientAdapter ---------- */

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = await _drain(requestStream);
    requests.add(RecordedRequest(
      method: options.method.toUpperCase(),
      path: options.path,
      uri: options.uri,
      queryParameters: Map<String, dynamic>.from(options.queryParameters),
      headers: Map<String, dynamic>.from(options.headers),
      data: options.data,
      bodyBytes: bytes,
    ));

    final r = _queue.isNotEmpty ? _queue.removeAt(0) : _always;
    if (r == null) {
      throw StateError(
        'FakeAdapter: "${options.method} ${options.path}" uchun javob '
        'rejalashtirilmagan (enqueue*/always* chaqiring).',
      );
    }
    if (r.delay != null) await Future<void>.delayed(r.delay!);
    if (r.error != null) throw r.error!;

    return ResponseBody.fromString(
      r.body,
      r.status,
      headers: <String, List<String>>{
        if (r.contentType != null) Headers.contentTypeHeader: [r.contentType!],
        ...r.extraHeaders,
      },
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }

  static Future<Uint8List> _drain(Stream<Uint8List>? s) async {
    if (s == null) return Uint8List(0);
    final out = <int>[];
    await for (final chunk in s) {
      out.addAll(chunk);
    }
    return Uint8List.fromList(out);
  }
}

/// `Response` obyektini tarmoqsiz yasash — `ApiClient.errorMessage`/`ok`
/// kabi sof funksiyalarni sinash uchun.
Response<Object?> fakeResponse(int? status, [Object? data, String path = '/x']) {
  return Response<Object?>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: data,
  );
}
