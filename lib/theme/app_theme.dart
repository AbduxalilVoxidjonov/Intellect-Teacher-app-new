import 'package:flutter/material.dart';

/// O'qituvchi portali rang palitrasi — web `.teacher-app` (index.css) bilan bir xil (TEAL + serif).
class AppColors {
  final Color accent;
  final Color accentD;
  final Color accentSoft;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color text;
  final Color muted;
  final Color faint;
  final Color border;
  final Color borderStrong;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color amber;
  final Color amberSoft;
  final List<BoxShadow> shadow;
  final bool isDark;

  const AppColors({
    required this.accent,
    required this.accentD,
    required this.accentSoft,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.muted,
    required this.faint,
    required this.border,
    required this.borderStrong,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.amber,
    required this.amberSoft,
    required this.shadow,
    required this.isDark,
  });

  static const light = AppColors(
    accent: Color(0xFF1F1F94), // navy-blue (brend)
    accentD: Color(0xFF020066), // brend navy (logo foni)
    accentSoft: Color(0xFFE8E8F6), // och navy tint
    bg: Color(0xFFFBFCFC), // paper
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F6F5), // paper2
    surface3: Color(0xFFF0F3F2), // line-soft
    text: Color(0xFF0F1A17), // ink
    muted: Color(0xFF5A6360),
    faint: Color(0xFF94A09B),
    border: Color(0xFFE7ECEB), // line
    borderStrong: Color(0xFFD7DEDC),
    green: Color(0xFF16A34A),
    greenSoft: Color(0xFFE7F6EC),
    red: Color(0xFFEF4444),
    redSoft: Color(0xFFFDEAEA),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFFFDF2E1),
    shadow: [BoxShadow(color: Color(0x0F0F1A17), blurRadius: 18, offset: Offset(0, 6))],
    isDark: false,
  );

  static const dark = AppColors(
    accent: Color(0xFF6E6BE6), // navy-blue (dark uchun yorug'roq)
    accentD: Color(0xFF4A47C4),
    accentSoft: Color(0xFF1E1E45),
    bg: Color(0xFF0E1513), // paper
    surface: Color(0xFF131C19), // paper2
    surface2: Color(0xFF16211D),
    surface3: Color(0xFF26322E), // line
    text: Color(0xFFE9EFED), // ink
    muted: Color(0xFF9AA6A2),
    faint: Color(0xFF6F7A76),
    border: Color(0xFF26322E), // line
    borderStrong: Color(0xFF32403B),
    green: Color(0xFF22C55E),
    greenSoft: Color(0xFF11271B),
    red: Color(0xFFF87171),
    redSoft: Color(0xFF2B1518),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0xFF2A2110),
    shadow: [BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8))],
    isDark: true,
  );
}

/// InheritedWidget orqali istalgan joyda `AppTheme.of(context)`.
class AppTheme extends InheritedWidget {
  final AppColors colors;
  const AppTheme({super.key, required this.colors, required super.child});

  static AppColors of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    return w?.colors ?? AppColors.light;
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) => oldWidget.colors.isDark != colors.isDark;
}

/// Web bilan mos radiuslar/o'lchamlar.
class AppSizes {
  static const double card = 18;
  static const double cardLg = 20;
  static const double chip = 8;
  static const double btn = 14;
  static const double pad = 16;
}

/// O'qituvchi ilovasi serif shrift ishlatadi (web'da Times New Roman).
const String kTeacherFontFamily = 'Times New Roman';

/// Brend rangi — logo foni (navy). Splash va login foni shu rangda bo'ladi,
/// shunda navy fonli logo hech qanday chekkasiz qo'shilib ketadi.
const Color kBrandNavy = Color(0xFF020066);
const List<String> kTeacherFontFallback = ['serif', 'Georgia'];

ThemeData buildMaterialTheme(AppColors c) {
  final base = c.isDark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    primaryColor: c.accent,
    colorScheme: base.colorScheme.copyWith(
      primary: c.accent,
      surface: c.surface,
      error: c.red,
    ),
    splashFactory: InkRipple.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: c.text,
      displayColor: c.text,
      fontFamily: kTeacherFontFamily,
      fontFamilyFallback: kTeacherFontFallback,
    ),
    dividerColor: c.border,
  );
}
