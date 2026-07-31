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
///     token backend'ga yuboriladi (`POST /teacher/push/register`).
///  3. Chiqishda `PushService.instance.clear()` — token backend'dan o'chiriladi.
///
/// Backend shu token orqali qurilmaga push yuboradi.

/// Ilova fon/yopiq holatida kelgan xabar (top-level bo'lishi shart).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Fon handleri alohida izolatda ishlaydi — Firebase'ni qayta init qilamiz.
  await Firebase.initializeApp();
  // Tizim tray'da ko'rsatishni OS o'zi bajaradi (notification payload bo'lsa).
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fln = FlutterLocalNotificationsPlugin();
  bool _inited = false;
  String? _lastToken;

  // DIQQAT: kanal ID'si AndroidManifest'dagi
  // `com.google.firebase.messaging.default_notification_channel_id` bilan bir xil
  // bo'lishi shart. Kanal sozlamalari yaratilgach o'zgarmaydi — sozlamani
  // o'zgartirsangiz ID'ni (_v2 → _v3) yangilang yoki ilovani qayta o'rnating.
  static const _channel = AndroidNotificationChannel(
    'intellect_teacher_v2',
    'Bildirishnomalar',
    description: 'Intellect Teacher push bildirishnomalari',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // Fon handleri.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Local notifications (foreground'da tray xabarini ko'rsatish uchun).
    const androidInit = AndroidInitializationSettings('ic_notification');
    const iosInit = DarwinInitializationSettings();
    await _fln.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Ruxsat so'rash (iOS + Android 13+).
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    // iOS'da foreground'da ham banner ko'rinsin.
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
    final n = m.notification;
    if (n == null) return;
    _fln.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
