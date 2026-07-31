import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Tanlangan fayl (nomi + baytlari).
class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);

  int get size => bytes.length;
}

/// Qurilmadan hujjat/rasm tanlash.
///
/// Android'da native `ACTION_OPEN_DOCUMENT` (MainActivity'dagi MethodChannel) ishlatiladi —
/// shunda PDF/DOCX kabi hujjatlarni ham tanlash mumkin va qo'shimcha paket kerak emas
/// (`file_picker` AGP 9 + built-in Kotlin talab qiladi, bu loyihada u yoqilmaydi).
/// iOS/boshqa platformalarda zaxira sifatida galereya (`image_picker`) ishlatiladi —
/// o'qituvchi test varag'ining rasmini yuklashi mumkin.
class FilePick {
  FilePick._();

  static const _channel = MethodChannel('uz.intellectcrm.teacher/file_pick');

  /// Standart ruxsat etilgan turlar — backend `UploadGuard` allowlist'iga mos.
  static const _defaultMimeTypes = <String>[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ];

  /// Fayl tanlash. Bekor qilinsa `null`, xatolik bo'lsa [Exception] otadi.
  static Future<PickedFile?> pick({List<String> mimeTypes = _defaultMimeTypes}) async {
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMapMethod<String, Object?>(
          'pick',
          {'mimeTypes': mimeTypes},
        );
        if (res == null) return null; // bekor qilindi
        final bytes = res['bytes'];
        final name = (res['name'] as String?) ?? 'fayl';
        if (bytes is! Uint8List || bytes.isEmpty) {
          throw Exception("Faylni o'qib bo'lmadi");
        }
        return PickedFile(name, bytes);
      } on PlatformException catch (e) {
        throw Exception(e.message ?? "Faylni tanlab bo'lmadi");
      }
    }

    // Zaxira: galereyadan rasm (iOS va h.k.).
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (img == null) return null;
    final bytes = await img.readAsBytes();
    return PickedFile(img.name, bytes);
  }
}
