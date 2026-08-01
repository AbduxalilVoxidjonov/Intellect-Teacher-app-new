import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../api/teacher_api.dart';

/// Firebase Cloud Messaging (push-bildirishnoma) xizmati.
///
/// Oqim:
///  1. `main()` da `Firebase.initializeApp()` + `PushService.instance.init()`.
///  2. Foydalanuvchi tizimga kirgach `PushService.instance.syncToken()` — FCM
///     token backend'ga yuboriladi (`POST /teacher/notifications/register`).
///  3. Chiqishda `PushService.instance.clear()` — token backend'dan o'chiriladi.
///
/// Backend shu token orqali qurilmaga push yuboradi.
///
/// OVOZ HAQIDA (Android 8+):
/// Bildirishnoma ovozini **kanal** belgilaydi, payload emas. Kanal sozlamalari
/// bir marta yaratilgach O'ZGARMAYDI — importance/playSound'ni o'zgartirish
/// uchun kanal ID'sini yangilash (v2 → v3) yoki ilovani qayta o'rnatish shart.
/// Shuning uchun quyida ID `_v3` va eski kanallar `deleteNotificationChannel`
/// bilan tozalanadi.

/// DIQQAT: bu ID AndroidManifest'dagi
/// `com.google.firebase.messaging.default_notification_channel_id` bilan
/// BIR XIL bo'lishi shart — aks holda FCM o'zining ovozsizroq zaxira kanalini
/// (`fcm_fallback_notification_channel`) yaratib yuboradi.
const String kPushChannelId = 'intellect_teacher_v3';

/// Ovoz/tebranish sozlamalari shu yerda — foreground va fon izolati bir xil
/// kanaldan foydalanishi uchun.
const AndroidNotificationChannel kPushChannel = AndroidNotificationChannel(
  kPushChannelId,
  'Bildirishnomalar',
  description: 'Intellect Teacher push bildirishnomalari',
  // max — heads-up banner + ovoz (high ham ovoz beradi, max ishonchliroq).
  importance: Importance.max,
  playSound: true, // sound: null → tizimning standart bildirishnoma ovozi
  enableVibration: true,
  enableLights: true,
  showBadge: true,
  audioAttributesUsage: AudioAttributesUsage.notification,
);

/// Eski/noto'g'ri sozlamali kanallar — sozlamalar o'zgarmagani uchun ularni
/// o'chirib tashlaymiz (aks holda Sozlamalarda ikkita "Bildirishnomalar"
/// ko'rinadi va eskisi ovozsiz qolishi mumkin).
const List<String> _legacyChannelIds = <String>[
  'intellect_teacher',
  'intellect_teacher_v2',
  // FCM manifestdagi kanalni topa olmaganda shuni yaratadi — sozlamasi past.
  'fcm_fallback_notification_channel',
];

/// Kanalni yaratadi (mavjud bo'lsa — hech narsa qilmaydi) va eskilarini
/// o'chiradi. Ham asosiy izolatdan, ham fon izolatidan chaqiriladi.
Future<void> _ensureChannel(FlutterLocalNotificationsPlugin fln) async {
  if (!Platform.isAndroid) return;
  final android = fln
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return;
  for (final id in _legacyChannelIds) {
    try {
      await android.deleteNotificationChannel(id);
    } catch (_) {}
  }
  await android.createNotificationChannel(kPushChannel);
}

/// Bir xil sozlamali `NotificationDetails` — ovoz doim yoqilgan.
NotificationDetails _details(String? body) => NotificationDetails(
      android: AndroidNotificationDetails(
        kPushChannel.id,
        kPushChannel.name,
        channelDescription: kPushChannel.description,
        importance: Importance.max,
        priority: Priority.high, // Android 7 va pastda heads-up + ovoz
        playSound: true, // sound: null → standart ovoz
        enableVibration: true,
        icon: 'ic_notification',
        ticker: 'Intellect Teacher',
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        // Uzun matn ochilib ko'rinsin.
        styleInformation:
            (body != null && body.length > 40) ? BigTextStyleInformation(body) : null,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true, // sound: null → standart APNs ovozi
      ),
    );

/// Payload'dan sarlavha/matnni oladi: `notification` bloki bo'lmasa
/// (data-only push) `data` ichidan qidiradi.
({String? title, String? body}) _extract(RemoteMessage m) {
  final n = m.notification;
  final d = m.data;
  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is String && v.trim().isNotEmpty) return v;
    }
    return null;
  }

  return (
    title: n?.title ?? pick(['title', 'Title', 'subject']),
    body: n?.body ?? pick(['body', 'Body', 'message', 'text']),
  );
}

int _notifId(RemoteMessage m) {
  final key = m.messageId ?? '${m.sentTime?.millisecondsSinceEpoch}${m.data}';
  // 32-bit musbat int — Android notification ID cheklovi.
  return key.hashCode & 0x7fffffff;
}

/// Ilova fon/yopiq holatida kelgan xabar (top-level bo'lishi shart).
///
/// `notification` bloki bo'lsa — tray xabarini FCM'ning o'zi ko'rsatadi
/// (manifestdagi default kanal → ovoz). Faqat data-only push kelganda biz
/// o'zimiz ko'rsatamiz, aks holda xabar umuman ko'rinmay ketadi.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Fon handleri alohida izolatda ishlaydi — Firebase'ni qayta init qilamiz.
  await Firebase.initializeApp();
  if (!Platform.isAndroid) return;
  if (message.notification != null) return; // OS allaqachon ko'rsatdi

  final t = _extract(message);
  if (t.title == null && t.body == null) return;

  final fln = FlutterLocalNotificationsPlugin();
  await fln.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
  );
  await _ensureChannel(fln);
  await fln.show(_notifId(message), t.title, t.body, _details(t.body));
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  String? _lastToken;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // Fon handleri.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Local notifications (foreground'da tray xabarini ko'rsatish uchun).
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    await _fln.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    // Kanal ilova ishga tushishi bilan yaratilsin: FCM yopiq holatda push
    // kelganda shu kanalni ishlatadi, mavjud bo'lmasa o'zi past sozlamali
    // zaxira kanal yasaydi.
    await _ensureChannel(_fln);

    // Ruxsat so'rash (iOS + Android 13+).
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    // Android 13+ POST_NOTIFICATIONS — qo'shimcha kafolat.
    if (Platform.isAndroid) {
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // iOS'da foreground'da ham banner + ovoz bo'lsin.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground'da kelgan xabarni local notification bilan ko'rsatamiz.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Token yangilanganda backend'ga qayta yuboramiz.
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _lastToken = t;
      _sendToBackend(t);
    });

    if (kDebugMode) await _logDiagnostics();
  }

  /// Tizimga kirgach chaqiriladi — token'ni olib backend'ga yuboradi.
  Future<void> syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _lastToken = token;
      // Test uchun: shu tokenni Firebase Console → Cloud Messaging → "Send test
      // message" ga qo'yib, backend'siz push kelishini tekshirish mumkin.
      debugPrint('[push] ============ FCM TOKEN ============');
      debugPrint('[push] $token');
      debugPrint('[push] ===================================');
      await _sendToBackend(token);
    } catch (e) {
      debugPrint('[push] syncToken error: $e');
    }
  }

  /// Chiqishda token'ni backend'dan o'chiradi.
  Future<void> clear() async {
    try {
      final token = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await TeacherApi.unregisterPushToken(token);
    } catch (_) {}
  }

  Future<void> _sendToBackend(String token) async {
    // Tizimga kirmagan bo'lsak yubormaymiz: endpoint `[Authorize]` — 401 qaytadi,
    // 401 esa `onUnauthorized` → logout'ni ishga tushiradi. `onTokenRefresh`
    // login'dan OLDIN ham otishi mumkin, shuning uchun shu qorovul kerak.
    if (ApiClient.token == null) {
      debugPrint('[push] token skipped: sessiya yo\'q (login qilinmagan)');
      return;
    }
    try {
      await TeacherApi.registerPushToken(
        token,
        Platform.isIOS ? 'ios' : 'android',
        // Uzun qurilma satrini cheklaymiz (web ham 80 belgi yuboradi).
        deviceName: _deviceName(),
      );
      debugPrint('[push] token backend\'ga yozildi');
    } on ApiException catch (e) {
      // Status kod bilan — 401 (sessiya tugagan), 403 (rol/ruxsat), 404 (server
      // eski) sabablarini ajratish uchun.
      debugPrint('[push] register token error: ${e.details}');
    } catch (e) {
      debugPrint('[push] register token error: $e');
    }
  }

  static String _deviceName() {
    final v = Platform.operatingSystemVersion;
    return v.length > 80 ? v.substring(0, 80) : v;
  }

  void _showForeground(RemoteMessage m) {
    final t = _extract(m);
    if (t.title == null && t.body == null) {
      debugPrint('[push] foreground: bo\'sh payload — ko\'rsatilmadi (${m.data})');
      return;
    }
    _fln.show(_notifId(m), t.title, t.body, _details(t.body));
  }

  /// Ovoz kelmasa sababini topish uchun: bildirishnoma yoqilganmi, kanal
  /// qanday importance bilan yaratilgan.
  Future<void> _logDiagnostics() async {
    if (!Platform.isAndroid) return;
    try {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      debugPrint('[push] notifications enabled: '
          '${await android.areNotificationsEnabled()}');
      final channels = await android.getNotificationChannels();
      for (final c in channels ?? const <AndroidNotificationChannel>[]) {
        debugPrint('[push] channel ${c.id} importance=${c.importance.value} '
            'sound=${c.playSound} vibration=${c.enableVibration}');
      }
    } catch (e) {
      debugPrint('[push] diagnostics error: $e');
    }
  }
}
