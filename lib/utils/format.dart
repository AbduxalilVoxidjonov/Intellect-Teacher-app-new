import 'package:flutter/material.dart';

/// Web `lib.tsx` bilan bir xil formatlash/rang yordamchilari.

const _months = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];
const _weekdays = [
  'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba',
];

/// 1–5 ball uchun BUTUN TIZIMDA yagona rang shkalasi — faqat YASHIL (emerald):
/// 1 uchun eng OCH, 5 uchun eng TO'Q. Web `gradeBadgeCls`/`gradeTextCls` bilan bir xil.
/// DIQQAT: avval ilovada "svetofor" (3 = sariq, 1–2 = qizil) ishlatilgan edi — shu sababli
/// jurnalda 3 baho olgan o'quvchi katagi sariq ko'rinardi. Web/PWA'da bunday emas.
int _gradeStep(num g) {
  final s = g.round() - 1;
  return s < 0 ? 0 : (s > 4 ? 4 : s);
}

/// Baho matni/chegarasi rangi (emerald 500→900).
Color gradeColor(num g) => const [
      Color(0xFF10B981), // emerald-500
      Color(0xFF059669), // emerald-600
      Color(0xFF047857), // emerald-700
      Color(0xFF065F46), // emerald-800
      Color(0xFF064E3B), // emerald-900
    ][_gradeStep(g)];

/// Baho katagi FONI (emerald 50→600) — web `gradeBadgeCls` bilan bir xil pog'onalar.
Color gradeCellBg(num g) => const [
      Color(0xFFECFDF5), // emerald-50
      Color(0xFFD1FAE5), // emerald-100
      Color(0xFFA7F3D0), // emerald-200
      Color(0xFF34D399), // emerald-400
      Color(0xFF059669), // emerald-600
    ][_gradeStep(g)];

/// Baho katagidagi MATN rangi — to'q fonlarda (4–5) oq.
Color gradeCellFg(num g) {
  final step = _gradeStep(g);
  if (step >= 3) return Colors.white;
  return const [
    Color(0xFF059669), // emerald-600
    Color(0xFF047857), // emerald-700
    Color(0xFF065F46), // emerald-800
  ][step];
}

const _subjPalette = [
  Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0D9488), Color(0xFFDB2777),
  Color(0xFFEA580C), Color(0xFFB45309), Color(0xFF16A34A), Color(0xFF0891B2),
  Color(0xFF4F46E5), Color(0xFF65A30D),
];

/// Fan nomidan barqaror rang.
Color subjectColor(String key) {
  if (key.isEmpty) return const Color(0xFF64708A);
  int hash = 0;
  for (final ch in key.codeUnits) {
    hash = (hash * 31 + ch) & 0x7fffffff;
  }
  return _subjPalette[hash % _subjPalette.length];
}

/// FISHdan bosh harflar (max 2).
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((w) => w[0]).join().toUpperCase();
}

/// Pulni "850 000" ko'rinishida (manfiy uchun "−").
String fmtMoney(num n, {bool withSign = false}) {
  final val = n.toDouble();
  final abs = val.abs().round();
  final s = abs.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  final sign = val < 0 ? '−' : (withSign && val > 0 ? '+' : '');
  return '$sign$buf';
}

DateTime? _parse(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final s = iso.trim();
  return DateTime.tryParse(s.length <= 10 ? '${s}T00:00:00' : s);
}

/// "12 Mart" yoki weekday=true bo'lsa "12 Mart, Dushanba".
String fmtDate(String? iso, {bool weekday = false}) {
  final d = _parse(iso);
  if (d == null) return iso ?? '';
  final wd = (d.weekday + 6) % 7; // Dushanba=0
  var s = '${d.day} ${_months[d.month - 1]}';
  if (weekday) s += ', ${_weekdays[wd]}';
  return s;
}

/// "2026-03" → "Mart 2026".
String fmtMonth(String? ym) {
  if (ym == null || ym.length < 7) return ym ?? '';
  final m = int.tryParse(ym.substring(5, 7)) ?? 0;
  return '${m >= 1 && m <= 12 ? _months[m - 1] : ym} ${ym.substring(0, 4)}';
}

/// "HH:mm".
String fmtTime(String? iso) {
  final d = _parse(iso);
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

List<String> get monthsUz => _months;
List<String> get weekdaysUz => _weekdays;
