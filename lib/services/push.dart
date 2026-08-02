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
  String? _lastToken;

  /// Ketayotgan `POST /register` — `clear()` uni kutadi (tartib muhim).
  Future<void>? _registering;

  /// `init()` TUGAGUNCHA saqlanadigan future. Avval `bool _inited` bayrog'i
  /// eng boshida `true` qilinardi — ikkinchi chaqiruv darhol qaytib ketardi va
  /// shu oynada kelgan push hali ishga tushmagan plagin ustida ko'rsatilardi.
  Future<void>? _initFuture;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {

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
      // DIQQAT: `debugPrint` RELEASE build'da ham ishlaydi. To'liq FCM token
      // logcat'ga tushsa, unga kira olgan har kim (ADB, MDM log yig'uvchi,
      // crash-reporter) o'qituvchining qurilmasiga push yubora oladi.
      // Shuning uchun to'liq token faqat debug'da chiqadi.
      if (kDebugMode) {
        // Test uchun: shu tokenni Firebase Console → Cloud Messaging → "Send
        // test message" ga qo'yib, backend'siz push kelishini tekshirish mumkin.
        debugPrint('[push] ============ FCM TOKEN ============');
        debugPrint('[push] $token');
        debugPrint('[push] ===================================');
      }
      await _sendToBackend(token);
    } catch (e) {
      debugPrint('[push] syncToken error: $e');
    }
  }

  /// Chiqishda token'ni backend'dan o'chiradi.
  ///
  /// QOROVUL: sessiya yo'q bo'lsa umuman so'rov yubormaymiz. Bunsiz cheksiz
  /// sikl bor edi — tokensiz `DELETE` → 401 → `logout()` → yana shu metod...
  Future<void> clear() async {
    if (ApiClient.token == null) {
      _lastToken = null;
      return;
    }
    try {
      // Ro'yxatdan o'tkazish so'rovi hali ketayotgan bo'lsa kutamiz: aks holda
      // `POST /register` `DELETE /register` dan KEYIN yetib borib, chiqqandan
      // so'ng ham qurilma push olishda davom etardi (umumiy telefonda muhim).
      await _registering;
      final token = _lastToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await TeacherApi.unregisterPushToken(token);
    } catch (_) {
    } finally {
      _lastToken = null;
    }
  }

  Future<void> _sendToBackend(String token) {
    final f = _register(token);
    _registering = f;
    return f;
  }

  Future<void> _register(String token) async {
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
      // eski) sabablarini ajratish uchun. Javob TANASI ataylab chiqarilmaydi:
      // `e.details` release logida serverning xom javobini oshkor qilardi.
      debugPrint('[push] register token error: [${e.statusCode ?? '-'}] ${e.message}');
    } catch (e) {
      debugPrint('[push] register token error: $e');
    }
  }

  static String _deviceName() {
    final v = Platform.operatingSystemVersion;
    return v.length > 80 ? v.substring(0, 80) : v;
  }

  void _showForeground(RemoteMessage m) {
    // iOS'da banner'ni OS'ning O'ZI ko'rsatadi
    // (`setForegroundNotificationPresentationOptions(alert: true, ...)`).
    // Bu yerda yana bir marta ko'rsatsak — ikkita banner va ikkita ovoz bo'lardi.
    // Android foreground'da hech nima ko'rsatmaydi, shuning uchun u yerda shart.
    if (!Platform.isAndroid) return;
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
