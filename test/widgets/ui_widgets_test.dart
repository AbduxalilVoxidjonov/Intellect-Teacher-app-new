// Shared UI kit (lib/widgets/ui.dart), SubScaffold va AppTheme uchun widget testlar.
//
// Bu fayl faqat WIDGET qismini qamraydi — sof rang funksiyalari (gradeCellBg/
// gradeColor/balanceColor ...) boshqa faylda tekshiriladi.
//
// Topilgan nuqsonlar shu yerda `// BUG-Uх` izohi bilan "qotirib" qo'yilgan:
// test HOZIRGI (noto'g'ri) xatti-harakatni tasdiqlaydi, kutilgan to'g'ri
// shartnoma esa `skip:` bilan yozilgan — tuzatilgach skip olib tashlanadi.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher/config.dart';
import 'package:teacher/screens/assignment_detail_screen.dart' show parseScoreInput;
import 'package:teacher/screens/contracts_screen.dart' show resolveFileUrl;
import 'package:teacher/screens/tabs/assignments_screen.dart' show parseMaxScoreInput;
import 'package:teacher/screens/tabs/messages_screen.dart';
import 'package:teacher/theme/app_theme.dart';
import 'package:teacher/widgets/sub_scaffold.dart';
import 'package:teacher/widgets/ui.dart';

import 'screen_harness.dart';

// ---------------------------------------------------------------------------
// Yordamchilar
// ---------------------------------------------------------------------------

/// Widgetni MaterialApp + AppTheme + Scaffold ichiga o'raydi.
Widget wrap(
  Widget child, {
  bool dark = false,
  double? textScale,
  AppColors? colors,
}) {
  return MaterialApp(
    home: AppTheme(
      colors: colors ?? (dark ? AppColors.dark : AppColors.light),
      child: Scaffold(
        body: Builder(
          builder: (ctx) {
            if (textScale == null) return child;
            return MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child,
            );
          },
        ),
      ),
    ),
  );
}

/// `widget` ichidagi BIRINCHI Container'ning BoxDecoration'i.
BoxDecoration? decorationOf(WidgetTester tester, Type widget) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(widget), matching: find.byType(Container)).first,
  );
  return container.decoration as BoxDecoration?;
}

double? progressValue(WidgetTester tester) => tester
    .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
    .value;

/// `AppColors.light` bilan bir xil `isDark` (false), lekin butunlay boshqa palitra.
/// BUG-U4 ni ko'rsatish uchun.
const AppColors lightVariant = AppColors(
  accent: Color(0xFFFF0000),
  accentD: Color(0xFFFF0001),
  accentSoft: Color(0xFFFF0002),
  bg: Color(0xFFFF0003),
  surface: Color(0xFFFF0004),
  surface2: Color(0xFFFF0005),
  surface3: Color(0xFFFF0006),
  text: Color(0xFFFF0007),
  muted: Color(0xFFFF0008),
  faint: Color(0xFFFF0009),
  border: Color(0xFFFF000A),
  borderStrong: Color(0xFFFF000B),
  green: Color(0xFFFF000C),
  greenSoft: Color(0xFFFF000D),
  red: Color(0xFFFF000E),
  redSoft: Color(0xFFFF000F),
  amber: Color(0xFFFF0010),
  amberSoft: Color(0xFFFF0011),
  shadow: <BoxShadow>[],
  isDark: false,
);

/// Palitrani almashtira oladigan host (AppTheme dependents'ni saqlab qoladi:
/// `child` HAR DOIM bir xil instance, shuning uchun u faqat InheritedWidget
/// xabari orqali qayta quriladi).
class ThemeSwapHost extends StatefulWidget {
  final Widget child;
  final AppColors initial;
  const ThemeSwapHost({super.key, required this.child, required this.initial});
  @override
  State<ThemeSwapHost> createState() => ThemeSwapHostState();
}

class ThemeSwapHostState extends State<ThemeSwapHost> {
  late AppColors _colors = widget.initial;
  void swap(AppColors c) => setState(() => _colors = c);
  @override
  Widget build(BuildContext context) =>
      AppTheme(colors: _colors, child: widget.child);
}

/// `TickerMode`ni test ichida yoqib/o'chirib turadigan host — qobiqdagi
/// (`shell.dart`) `IndexedStack` + `TickerMode` juftligini taqlid qiladi.
class TickerHost extends StatefulWidget {
  final Widget child;
  const TickerHost({super.key, required this.child});
  @override
  State<TickerHost> createState() => TickerHostState();
}

class TickerHostState extends State<TickerHost> {
  bool _enabled = true;
  void setEnabled(bool v) => setState(() => _enabled = v);
  @override
  Widget build(BuildContext context) =>
      TickerMode(enabled: _enabled, child: widget.child);
}

/// `AppTheme.of` natijasini yozib boradigan zond.
class ColorProbe extends StatelessWidget {
  final void Function(AppColors) onBuild;
  const ColorProbe({super.key, required this.onBuild});
  @override
  Widget build(BuildContext context) {
    onBuild(AppTheme.of(context));
    return const SizedBox.shrink();
  }
}

void main() {
  // -------------------------------------------------------------------------
  // 1. Har bir public widget ikkala mavzuda ham xatosiz chiziladi
  // -------------------------------------------------------------------------
  group('smoke — barcha public widgetlar light/dark da chiziladi', () {
    final cases = <String, Widget>{
      'SCard': const SCard(child: Text('card')),
      'SCard (onTap)': SCard(onTap: () {}, child: const Text('card tap')),
      'ScreenHeader': const ScreenHeader('Sarlavha',
          subtitle: Text('sub'), trailing: Icon(Icons.more_horiz)),
      'SectionTitle': const SectionTitle('Bo\'lim', trailing: Icon(Icons.add)),
      'SChip': const SChip('chip', color: Colors.teal),
      'ProgressBar': const ProgressBar(0.42),
      'Ring': const Ring(value: 40, center: Text('40')),
      'Avatar': const Avatar(name: 'Ali Valiyev'),
      'EmptyState': const EmptyState(text: 'Hech narsa yo\'q'),
      'Loader': const Loader(label: 'Yuklanmoqda'),
      'SButton': const SButton('Tugma'),
      'GradeBox': const GradeBox(4),
      'GradeBox (null)': const GradeBox(null),
    };

    for (final entry in cases.entries) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key} — ${dark ? 'dark' : 'light'}',
            (tester) async {
          await tester.pumpWidget(wrap(entry.value, dark: dark));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byWidget(entry.value), findsOneWidget);
        });
      }
    }

    testWidgets('SButton — barcha BtnKind variantlari', (tester) async {
      for (final kind in BtnKind.values) {
        await tester.pumpWidget(
          wrap(SButton('K-${kind.name}', kind: kind, icon: Icons.check, onTap: () {})),
        );
        expect(find.text('K-${kind.name}'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 2. SCard
  // -------------------------------------------------------------------------
  group('SCard', () {
    testWidgets('mavzu surface rangini oladi, custom color ustun turadi',
        (tester) async {
      await tester.pumpWidget(wrap(const SCard(child: Text('x'))));
      expect(decorationOf(tester, SCard)!.color, AppColors.light.surface);

      await tester.pumpWidget(wrap(const SCard(child: Text('x')), dark: true));
      expect(decorationOf(tester, SCard)!.color, AppColors.dark.surface);

      await tester.pumpWidget(
        wrap(const SCard(color: Color(0xFF123456), child: Text('x'))),
      );
      expect(decorationOf(tester, SCard)!.color, const Color(0xFF123456));
    });

    testWidgets('onTap == null bo\'lsa bosish hodisasi yo\'q, aks holda ishlaydi',
        (tester) async {
      await tester.pumpWidget(wrap(const SCard(child: Text('statik'))));
      expect(find.byType(GestureDetector), findsNothing);

      var taps = 0;
      await tester.pumpWidget(
        wrap(SCard(onTap: () => taps++, child: const Text('bosiladi'))),
      );
      await tester.tap(find.text('bosiladi'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });

  // -------------------------------------------------------------------------
  // 3. SChip / SectionTitle / ScreenHeader
  // -------------------------------------------------------------------------
  group('SChip', () {
    testWidgets('matn chiqadi, fon rangi color.alpha(0.13) yoki bg', (tester) async {
      await tester.pumpWidget(wrap(const SChip('Faol', color: Color(0xFF00FF00))));
      expect(find.text('Faol'), findsOneWidget);
      final auto = decorationOf(tester, SChip)!.color!;
      expect(auto.a, closeTo(0.13, 0.01));

      await tester.pumpWidget(wrap(
        const SChip('Faol', color: Color(0xFF00FF00), bg: Color(0xFF0000FF)),
      ));
      expect(decorationOf(tester, SChip)!.color, const Color(0xFF0000FF));
    });
  });

  testWidgets('ScreenHeader/SectionTitle sarlavha va trailing ni chizadi',
      (tester) async {
    await tester.pumpWidget(wrap(const Column(children: [
      ScreenHeader('Bosh sahifa', trailing: Icon(Icons.settings)),
      SectionTitle('Guruhlar', trailing: Icon(Icons.add)),
    ])));
    expect(find.text('Bosh sahifa'), findsOneWidget);
    expect(find.text('Guruhlar'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 4. SButton
  // -------------------------------------------------------------------------
  group('SButton', () {
    testWidgets('label va icon chiqadi', (tester) async {
      await tester.pumpWidget(
        wrap(SButton('Saqlash', icon: Icons.save, onTap: () {})),
      );
      expect(find.text('Saqlash'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    testWidgets('onTap bosilganda ishga tushadi', (tester) async {
      var hits = 0;
      await tester.pumpWidget(wrap(SButton('Bos', onTap: () => hits++)));
      await tester.tap(find.byType(SButton));
      await tester.pumpAndSettle();
      expect(hits, 1);
    });

    testWidgets('loading: true — indikator ko\'rinadi, label yashiriladi, bosish inkor',
        (tester) async {
      var hits = 0;
      await tester.pumpWidget(
        wrap(SButton('Bos', loading: true, onTap: () => hits++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Bos'), findsNothing);

      await tester.tap(find.byType(SButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(hits, 0, reason: 'loading holatida onTap chaqirilmasligi kerak');

      // Opacity 0.5 — vizual "disabled".
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(SButton), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('onTap == null — disabled (InkWell.onTap null, opacity 0.5)',
        (tester) async {
      await tester.pumpWidget(wrap(const SButton('O\'chiq')));
      final ink = tester.widget<InkWell>(
        find.descendant(of: find.byType(SButton), matching: find.byType(InkWell)).first,
      );
      expect(ink.onTap, isNull);
      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(SButton), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 0.5);

      await tester.tap(find.byType(SButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('bgColor/fgColor override qiladi', (tester) async {
      await tester.pumpWidget(wrap(SButton(
        'Oq',
        bgColor: const Color(0xFFFFFFFF),
        fgColor: const Color(0xFF020066),
        onTap: () {},
      )));
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(SButton), matching: find.byType(Material)).first,
      );
      expect(material.color, const Color(0xFFFFFFFF));
      final text = tester.widget<Text>(find.text('Oq'));
      expect(text.style!.color, const Color(0xFF020066));
    });

    testWidgets('large: true — balandlik 56, aks holda 50', (tester) async {
      await tester.pumpWidget(wrap(SButton('K', onTap: () {})));
      expect(tester.getSize(find.byType(SButton)).height, 50);

      await tester.pumpWidget(wrap(SButton('K', large: true, onTap: () {})));
      expect(tester.getSize(find.byType(SButton)).height, 56);
    });
  });

  // -------------------------------------------------------------------------
  // 5. ProgressBar  (BUG-U1)
  // -------------------------------------------------------------------------
  group('ProgressBar', () {
    testWidgets('0 / 0.5 / 1 qiymatlari to\'g\'ri uzatiladi', (tester) async {
      for (final v in [0.0, 0.5, 1.0]) {
        await tester.pumpWidget(wrap(ProgressBar(v)));
        expect(progressValue(tester), v);
      }
    });

    testWidgets('mavzu ranglari: track surface3, fill accent (yoki override)',
        (tester) async {
      await tester.pumpWidget(wrap(const ProgressBar(0.5)));
      var bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.backgroundColor, AppColors.light.surface3);
      expect(bar.valueColor!.value, AppColors.light.accent);

      await tester.pumpWidget(wrap(const ProgressBar(0.5), dark: true));
      bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.backgroundColor, AppColors.dark.surface3);
      expect(bar.valueColor!.value, AppColors.dark.accent);

      await tester
          .pumpWidget(wrap(const ProgressBar(0.5, color: Color(0xFFAA00AA))));
      bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.valueColor!.value, const Color(0xFFAA00AA));
    });

    testWidgets('height minHeight ga uzatiladi', (tester) async {
      await tester.pumpWidget(wrap(const ProgressBar(0.5, height: 14)));
      expect(
        tester
            .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
            .minHeight,
        14,
      );
    });

    testWidgets('manfiy qiymat 0 ga qisiladi', (tester) async {
      await tester.pumpWidget(wrap(const ProgressBar(-5)));
      expect(progressValue(tester), 0.0);
    });

    // BUG-U1 (TUZATILDI) — ui.dart. `value.clamp(0, 1)` Dart'ning `num.compareTo`
    // total-order semantikasiga tayanardi: NaN HAMMADAN katta hisoblanadi,
    // shuning uchun `double.nan.clamp(0, 1) == 1.0` va progress "100% to'la"
    // ko'rinardi. Endi yaroqsiz qiymat ANIQLANMAGAN (null) progress beradi.
    // Eski pin testlar (1.0 kutgan) o'chirildi.
    testWidgets(
      'BUG-U1 (shartnoma): NaN aniqlanmagan progress yoki 0 bo\'lishi kerak',
      (tester) async {
        await tester.pumpWidget(wrap(const ProgressBar(double.nan)));
        expect(tester.takeException(), isNull);
        final v = progressValue(tester);
        expect(v == null || v == 0.0, isTrue,
            reason: 'NaN "to\'liq bajarildi" degani emas');
        expect(v, isNot(1.0));
      },
    );

    testWidgets(
      'BUG-U1 (shartnoma): infinity 1.0 emas, aniqlanmagan bo\'lishi kerak',
      (tester) async {
        await tester.pumpWidget(wrap(const ProgressBar(double.infinity)));
        expect(tester.takeException(), isNull);
        final v = progressValue(tester);
        expect(v == null || v == 0.0, isTrue);
        expect(v, isNot(1.0));
      },
    );

    testWidgets('BUG-U1: -infinity ham aniqlanmagan (yolg\'on 0% emas)',
        (tester) async {
      await tester.pumpWidget(wrap(const ProgressBar(double.negativeInfinity)));
      expect(tester.takeException(), isNull);
      final v = progressValue(tester);
      expect(v == null || v == 0.0, isTrue);
    });

    testWidgets('BUG-U1: chekli qiymatlar avvalgidek qirqiladi', (tester) async {
      await tester.pumpWidget(wrap(const ProgressBar(5)));
      expect(progressValue(tester), 1.0);
      await tester.pumpWidget(wrap(const ProgressBar(-5)));
      expect(progressValue(tester), 0.0);
      await tester.pumpWidget(wrap(const ProgressBar(0.25)));
      expect(progressValue(tester), 0.25);
    });
  });

  // -------------------------------------------------------------------------
  // 6. Ring
  // -------------------------------------------------------------------------
  group('Ring', () {
    testWidgets('size bo\'yicha joy egallaydi va center widget chiqadi',
        (tester) async {
      await tester.pumpWidget(
        wrap(const Center(child: Ring(value: 75, size: 90, center: Text('75%')))),
      );
      expect(tester.getSize(find.byType(Ring)), const Size(90, 90));
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('max <= 0 bo\'lsa nol bilan bo\'lish yo\'q', (tester) async {
      await tester.pumpWidget(wrap(const Center(child: Ring(value: 5, max: 0))));
      expect(tester.takeException(), isNull);
    });

    testWidgets('value > max — chizishda xato bermaydi', (tester) async {
      await tester
          .pumpWidget(wrap(const Center(child: Ring(value: 500, max: 100))));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 7. EmptyState / Loader
  // -------------------------------------------------------------------------
  group('EmptyState', () {
    testWidgets('default ikonka + matn', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(text: 'Ma\'lumot yo\'q')));
      expect(find.text('Ma\'lumot yo\'q'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('custom ikonka uzatiladi', (tester) async {
      await tester.pumpWidget(
        wrap(const EmptyState(icon: Icons.school_outlined, text: 'Guruh yo\'q')),
      );
      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('bo\'sh matn bilan ham xato bermaydi', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(text: '')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('uzun matn tor (200px) konteynerda GORIZONTAL toshmaydi (o\'raladi)',
        (tester) async {
      await tester.pumpWidget(wrap(SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 200,
            child: EmptyState(text: 'Juda uzun matn ' * 20),
          ),
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(EmptyState)).width, 200);
    });

    // NEW-1 (TUZATILDI) — EmptyState ichida scroll'siz `Column` + 48px vertikal
    // padding bor edi, shuning uchun balandligi CHEKLANGAN joyda (scroll'siz
    // Scaffold, sheet, karta ichi) uzun matn "RenderFlex overflowed ... on the
    // bottom" berardi. Endi cheklangan balandlikda kontent scroll qilinadi.
    testWidgets('NEW-1: cheklangan balandlikda uzun matn TOSHMAYDI',
        (tester) async {
      await tester.pumpWidget(wrap(Center(
        child: SizedBox(
          width: 200,
          height: 120,
          child: EmptyState(text: 'Juda uzun matn ' * 20),
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(tester.getSize(find.byType(EmptyState)), const Size(200, 120));
      // Sig'magan kontent scroll qilinadi.
      expect(
        find.descendant(
            of: find.byType(EmptyState), matching: find.byType(Scrollable)),
        findsOneWidget,
      );
    });

    testWidgets('NEW-1: balandlik cheklanmagan bo\'lsa scroll qo\'shilmaydi',
        (tester) async {
      // ListView bolasi — bu yerda SingleChildScrollView "unbounded height"
      // xatosini bergan bo'lardi.
      await tester.pumpWidget(wrap(ListView(
        children: const [EmptyState(text: 'Ma\'lumot yo\'q')],
      )));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
            of: find.byType(EmptyState), matching: find.byType(Scrollable)),
        findsNothing,
      );
    });
  });

  group('Loader', () {
    testWidgets('label\'siz — faqat indikator', (tester) async {
      await tester.pumpWidget(wrap(const Loader()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('label bilan — matn ham chiqadi', (tester) async {
      await tester.pumpWidget(wrap(const Loader(label: 'Yuklanmoqda...')));
      expect(find.text('Yuklanmoqda...'), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(indicator.color, AppColors.light.accent);
    });

    testWidgets('uzun label tor konteynerda gorizontal toshmaydi', (tester) async {
      await tester.pumpWidget(wrap(SingleChildScrollView(
        child: SizedBox(
          width: 200,
          child: Loader(label: 'Juda uzun yuklanish matni ' * 15),
        ),
      )));
      expect(tester.takeException(), isNull);
    });

    // NEW-1 (TUZATILDI, davomi) — Loader ham xuddi shunday edi.
    testWidgets('NEW-1: Loader uzun label bilan cheklangan balandlikda toshmaydi',
        (tester) async {
      await tester.pumpWidget(wrap(Center(
        child: SizedBox(
          width: 200,
          height: 100,
          child: Loader(label: 'Juda uzun yuklanish matni ' * 15),
        ),
      )));
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Loader), matching: find.byType(Scrollable)),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // 8. GradeBox  (BUG-U2)
  // -------------------------------------------------------------------------
  group('GradeBox', () {
    testWidgets('null — "—" belgisi, fon yo\'q', (tester) async {
      await tester.pumpWidget(wrap(const Center(child: GradeBox(null))));
      expect(find.text('—'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(GradeBox), matching: find.byType(Container)),
        findsNothing,
      );
      expect(tester.getSize(find.byType(GradeBox)), const Size(30, 30));
    });

    testWidgets('1–5 baholari HAR XIL (och → to\'q) rangda chiziladi',
        (tester) async {
      final seen = <int, Color>{};
      for (var g = 1; g <= 5; g++) {
        await tester.pumpWidget(wrap(Center(child: GradeBox(g))));
        expect(find.text('$g'), findsOneWidget);
        seen[g] = decorationOf(tester, GradeBox)!.color!;
      }
      expect(seen.values.toSet().length, 5,
          reason: '1–5 uchun beshta farqli fon bo\'lishi kerak');
      // Emerald shkalasi: 1 eng och, 5 eng to'q.
      expect(seen[1], const Color(0xFFECFDF5));
      expect(seen[5], const Color(0xFF059669));
    });

    testWidgets('4–5 da matn oq, 1–3 da to\'q yashil', (tester) async {
      await tester.pumpWidget(wrap(Center(child: const GradeBox(5))));
      expect(tester.widget<Text>(find.text('5')).style!.color, Colors.white);

      await tester.pumpWidget(wrap(Center(child: const GradeBox(1))));
      expect(tester.widget<Text>(find.text('1')).style!.color, isNot(Colors.white));
    });

    testWidgets('butun son .0 siz chiziladi (4.0 → "4")', (tester) async {
      await tester.pumpWidget(wrap(const Center(child: GradeBox(4.0))));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('4.0'), findsNothing);
    });

    // BUG-U2 (TUZATILDI — chaqiruv joyida): GradeBox ATAYLAB 1–5 jurnal
    // shkalasi uchun qoladi (quyidagi ikki test uni hujjatlashtiradi), topshiriq
    // ballari (0–100) endi `ScoreBadge` bilan chiziladi — pastdagi "ScoreBadge"
    // guruhiga qarang. `assignment_detail_screen.dart` ham shunga ko'chirildi.
    testWidgets('GradeBox 1–5 uchun: >= 5 bo\'lgan hamma qiymat bir xil rangda',
        (tester) async {
      final colors = <num, Color>{};
      for (final score in <num>[5, 20, 50, 87.5, 100]) {
        await tester.pumpWidget(wrap(Center(child: GradeBox(score))));
        colors[score] = decorationOf(tester, GradeBox)!.color!;
      }
      // BUG-U2 — hozirgi xatti-harakat: hammasi bitta rang.
      expect(colors.values.toSet().length, 1);
      expect(colors[100], const Color(0xFF059669));
      // 5 ballik "a'lo" va 5/100 ballik "juda yomon" bir xil ko'rinadi:
      expect(colors[5], colors[100]);
    });

    // GradeBox qat'iy 30x30 — kasrli 0–100 ball unga SIG'MAYDI (shu sababli
    // topshiriq ballari uchun ScoreBadge kerak bo'ldi).
    testWidgets('GradeBox: 87.5 matni 30x30 katakdan kengroq (kesiladi)',
        (tester) async {
      await tester.pumpWidget(wrap(const Center(child: GradeBox(87.5))));
      await tester.pump();
      // Flutter RenderParagraph gorizontal toshishda istisno OTMAYDI — matn
      // jimgina kesiladi, shuning uchun bu nuqson testda "ko'rinmaydi".
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GradeBox)), const Size(30, 30));

      // Xuddi shu matnning tabiiy kengligi — 30px dan katta ekanini o'lchaymiz.
      await tester.pumpWidget(wrap(const Center(
        child: Text('87.5',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      )));
      final natural = tester.getSize(find.text('87.5')).width;
      // BUG-U2 — kerakli kenglik katak kengligidan katta.
      expect(natural, greaterThan(30));
    });

    testWidgets('0 va manfiy baho ham xatosiz (eng och rang)', (tester) async {
      for (final g in <num>[0, -3]) {
        await tester.pumpWidget(wrap(Center(child: GradeBox(g))));
        expect(tester.takeException(), isNull);
        expect(decorationOf(tester, GradeBox)!.color, const Color(0xFFECFDF5));
      }
    });
  });

  // -------------------------------------------------------------------------
  // 8b. ScoreBadge — BUG-U2 ning haqiqiy tuzatilishi
  // -------------------------------------------------------------------------
  //
  // BUG-U2 shartnomasi endi shu widgetga qaratilgan: topshiriq ballari
  // `GradeBox` (1–5) bilan emas, `ScoreBadge` bilan chiziladi.
  group('ScoreBadge (BUG-U2 TUZATILDI)', () {
    testWidgets('BUG-U2 shartnoma: 0–100 ballar bir-biridan farqli rangda',
        (tester) async {
      final colors = <Color>{};
      for (final score in <num>[10, 40, 70, 100]) {
        await tester.pumpWidget(wrap(Center(child: ScoreBadge(score: score))));
        colors.add(decorationOf(tester, ScoreBadge)!.color!);
      }
      expect(colors.length, 4, reason: 'har bir daraja o\'z rangida');
    });

    testWidgets('BUG-U2 shartnoma: kasrli ball to\'liq ko\'rinadi (kesilmaydi)',
        (tester) async {
      await tester
          .pumpWidget(wrap(const Center(child: ScoreBadge(score: 87.5))));
      expect(tester.takeException(), isNull);
      expect(find.text('87.5/100'), findsOneWidget);

      final shown = tester.getSize(find.text('87.5/100')).width;
      await tester.pumpWidget(wrap(const Center(
        child: Text('87.5/100',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      )));
      final natural = tester.getSize(find.text('87.5/100')).width;
      expect(shown, natural, reason: 'matn qisilmagan/kesilmagan');
    });

    testWidgets('BUG-U2 shartnoma: 5/5 va 5/100 bir xil KO\'RINMAYDI',
        (tester) async {
      await tester.pumpWidget(
          wrap(const Center(child: ScoreBadge(score: 5, maxScore: 5))));
      final excellent = decorationOf(tester, ScoreBadge)!.color!;
      expect(find.text('5/5'), findsOneWidget);

      await tester.pumpWidget(
          wrap(const Center(child: ScoreBadge(score: 5, maxScore: 100))));
      final terrible = decorationOf(tester, ScoreBadge)!.color!;
      expect(find.text('5/100'), findsOneWidget);

      expect(excellent, isNot(terrible));
      expect(excellent, AppColors.light.greenSoft);
      expect(terrible, AppColors.light.redSoft);
    });

    testWidgets('butun son .0 siz, null esa "—"', (tester) async {
      await tester.pumpWidget(
          wrap(const Center(child: ScoreBadge(score: 8.0, maxScore: 10))));
      expect(find.text('8/10'), findsOneWidget);

      await tester
          .pumpWidget(wrap(const Center(child: ScoreBadge(score: null))));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('maxScore 0 / yaroqsiz ball xatosiz chiziladi', (tester) async {
      await tester.pumpWidget(
          wrap(const Center(child: ScoreBadge(score: 7, maxScore: 0))));
      expect(tester.takeException(), isNull);
      expect(find.text('7'), findsOneWidget);

      await tester.pumpWidget(
          wrap(const Center(child: ScoreBadge(score: double.nan))));
      expect(tester.takeException(), isNull);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('tor joyda ham toshmaydi', (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: SizedBox(width: 40, child: ScoreBadge(score: 87.5)),
      )));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 9. Avatar  (BUG-U3)
  // -------------------------------------------------------------------------
  group('Avatar', () {
    testWidgets('ism bo\'yicha bosh harflar (max 2)', (tester) async {
      await tester.pumpWidget(
        wrap(const Center(child: Avatar(name: 'Abduxalil Voxidjonov'))),
      );
      expect(find.text('AV'), findsOneWidget);
    });

    testWidgets('bo\'sh ism — "?"', (tester) async {
      await tester.pumpWidget(wrap(const Center(child: Avatar(name: '   '))));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('doira + gradient, size bo\'yicha o\'lcham', (tester) async {
      await tester
          .pumpWidget(wrap(const Center(child: Avatar(name: 'Ali', size: 64))));
      expect(tester.getSize(find.byType(Avatar)), const Size(64, 64));
      final d = decorationOf(tester, Avatar)!;
      expect(d.shape, BoxShape.circle);
      expect(d.gradient, isA<LinearGradient>());
      expect((d.gradient! as LinearGradient).colors.first, AppColors.light.accent);
    });

    testWidgets('bo\'sh imageUrl ("") — baribir bosh harflar', (tester) async {
      await tester.pumpWidget(
        wrap(const Center(child: Avatar(name: 'Ali Valiyev', imageUrl: ''))),
      );
      expect(find.text('AV'), findsOneWidget);
      expect(decorationOf(tester, Avatar)!.image, isNull);
    });

    // BUG-U3 (TUZATILDI) — avval `DecorationImage(image: NetworkImage(...))`
    // ishlatilardi, unda `onError`/fallback YO'Q: imageUrl berilishi bilan bosh
    // harflar butunlay olib tashlanar (`child: null`) va rasm yuklanmasa
    // (404, oflayn, yaroqsiz URL) foydalanuvchi BO'SH gradient doira ko'rardi.
    // Eski pin test o'chirildi.
    testWidgets(
      'BUG-U3 (shartnoma): rasm yuklanmasa bosh harflarga qaytadi',
      (tester) async {
        await tester.pumpWidget(wrap(const Center(
          child: Avatar(name: 'Ali Valiyev', imageUrl: 'https://example.test/yoq.png'),
        )));
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
        expect(find.text('AV'), findsOneWidget);
      },
    );

    testWidgets('BUG-U3: rasm yuklanayotganda ham bosh harflar ko\'rinadi',
        (tester) async {
      await tester.pumpWidget(wrap(const Center(
        child: Avatar(name: 'Ali Valiyev', imageUrl: 'https://example.test/rasm.png'),
      )));
      await tester.pump();
      expect(find.text('AV'), findsOneWidget);
      // Doira + gradient saqlanadi, `DecorationImage` esa endi ishlatilmaydi.
      final d = decorationOf(tester, Avatar)!;
      expect(d.shape, BoxShape.circle);
      expect(d.image, isNull);
      tester.takeException();
    });
  });

  // -------------------------------------------------------------------------
  // 10. SubScaffold
  // -------------------------------------------------------------------------
  group('SubScaffold', () {
    testWidgets('sarlavha, orqaga tugmasi va kontent chiziladi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppTheme(
          colors: AppColors.light,
          child: SubScaffold(title: 'Sozlamalar', child: Text('kontent')),
        ),
      ));
      expect(find.text('Sozlamalar'), findsOneWidget);
      expect(find.text('kontent'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });

    testWidgets('dark mavzuda ham fon rangi mavzudan olinadi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppTheme(
          colors: AppColors.dark,
          child: SubScaffold(title: 'Qorong\'i', child: SizedBox()),
        ),
      ));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.dark.bg);
    });

    testWidgets('showBack: false — orqaga tugmasi yo\'q', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppTheme(
          colors: AppColors.light,
          child: SubScaffold(title: 'Root', showBack: false, child: SizedBox()),
        ),
      ));
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
    });

    testWidgets('actions chiziladi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppTheme(
          colors: AppColors.light,
          child: SubScaffold(
            title: 'Amallar',
            actions: const [Icon(Icons.delete_outline)],
            child: const SizedBox(),
          ),
        ),
      ));
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('scrollable: true — SingleChildScrollView qo\'shiladi',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppTheme(
          colors: AppColors.light,
          child: SubScaffold(
            title: 'Uzun',
            scrollable: true,
            child: Column(
              children: List.generate(60, (i) => SizedBox(height: 40, child: Text('r$i'))),
            ),
          ),
        ),
      ));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('orqaga tugmasi route\'ni pop qiladi', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppTheme(
          colors: AppColors.light,
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                    builder: (_) => const SubScaffold(
                      title: 'Ichki ekran',
                      child: Text('ichki'),
                    ),
                  )),
                  child: const Text('ochish'),
                ),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('ochish'));
      await tester.pumpAndSettle();
      expect(find.text('Ichki ekran'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Ichki ekran'), findsNothing);
      expect(find.text('ochish'), findsOneWidget);
    });

    testWidgets('root route\'da orqaga bosilsa ilova qulamaydi (maybePop)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const AppTheme(
          colors: AppColors.light,
          child: SubScaffold(title: 'Root', child: Text('root')),
        ),
      ));
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 11. AppTheme InheritedWidget  (BUG-U4)
  // -------------------------------------------------------------------------
  group('AppTheme', () {
    testWidgets('of(context) berilgan palitrani qaytaradi', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(wrap(ColorProbe(onBuild: (c) => seen = c)));
      expect(identical(seen, AppColors.light), isTrue);

      await tester
          .pumpWidget(wrap(ColorProbe(onBuild: (c) => seen = c), dark: true));
      expect(identical(seen, AppColors.dark), isTrue);
      expect(seen.isDark, isTrue);
    });

    testWidgets('AppTheme yo\'q bo\'lsa — light default', (tester) async {
      late AppColors seen;
      await tester.pumpWidget(MaterialApp(
        home: ColorProbe(onBuild: (c) => seen = c),
      ));
      expect(identical(seen, AppColors.light), isTrue);
    });

    testWidgets('isDark o\'zgarsa dependents QAYTA quriladi', (tester) async {
      final key = GlobalKey<ThemeSwapHostState>();
      final builds = <AppColors>[];
      final probe = ColorProbe(onBuild: builds.add);

      await tester.pumpWidget(MaterialApp(
        home: ThemeSwapHost(key: key, initial: AppColors.light, child: probe),
      ));
      expect(builds.length, 1);

      key.currentState!.swap(AppColors.dark);
      await tester.pump();
      expect(builds.length, 2);
      expect(identical(builds.last, AppColors.dark), isTrue);
    });

    // BUG-U4 (TUZATILDI) — avval:
    //   `updateShouldNotify(old) => old.colors.isDark != colors.isDark;`
    // Faqat `isDark` solishtirilardi, shuning uchun bir xil `isDark` bilan
    // BOSHQA palitraga o'tilsa (brend rangini almashtirish, A/B palitra)
    // dependents umuman xabardor qilinmasdi. Eski pin testlar o'chirildi.
    testWidgets(
      'BUG-U4 (shartnoma): palitra o\'zgarsa dependents yangi ranglarni oladi',
      (tester) async {
        final key = GlobalKey<ThemeSwapHostState>();
        final builds = <AppColors>[];
        final probe = ColorProbe(onBuild: builds.add);

        await tester.pumpWidget(MaterialApp(
          home: ThemeSwapHost(key: key, initial: AppColors.light, child: probe),
        ));
        expect(builds.length, 1);
        key.currentState!.swap(lightVariant);
        await tester.pump();

        expect(builds.length, 2);
        expect(builds.last.accent, lightVariant.accent);
      },
    );

    testWidgets('BUG-U4: SCard yangi surface rangini oladi', (tester) async {
      final key = GlobalKey<ThemeSwapHostState>();
      const card = SCard(child: Text('x'));

      await tester.pumpWidget(MaterialApp(
        home: ThemeSwapHost(
          key: key,
          initial: AppColors.light,
          child: const Scaffold(body: card),
        ),
      ));
      expect(decorationOf(tester, SCard)!.color, AppColors.light.surface);

      key.currentState!.swap(lightVariant);
      await tester.pump();
      expect(decorationOf(tester, SCard)!.color, lightVariant.surface);
    });

    testWidgets('BUG-U4: bir xil palitra qayta berilsa ortiqcha qurish yo\'q',
        (tester) async {
      final key = GlobalKey<ThemeSwapHostState>();
      final builds = <AppColors>[];
      final probe = ColorProbe(onBuild: builds.add);

      await tester.pumpWidget(MaterialApp(
        home: ThemeSwapHost(key: key, initial: AppColors.light, child: probe),
      ));
      key.currentState!.swap(AppColors.light);
      await tester.pump();
      expect(builds.length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // 12. Katta shrift (accessibility) + tor konteynerlar  (BUG-U5)
  // -------------------------------------------------------------------------
  //
  // Eslatma: `lib/screens/shell.dart` ni yakka holda pump qilib bo'lmaydi —
  // `_ShellScreenState` maydon initializer'ida 5 ta tab ekranini
  // (Dashboard/Rating/Tests/Messages/Profile) yaratadi, ular esa initState'da
  // API chaqiradi (tarmoq I/O) va Session/DI talab qiladi. Pastki nav bar
  // (`_TabItem`) private. Shuning uchun UI-kit widgetlari alohida sinaladi.
  group('accessibility — textScaler 2.5', () {
    Future<Object?> pumpScaled(WidgetTester tester, Widget child,
        {double scale = 2.5}) async {
      await tester.pumpWidget(wrap(child, textScale: scale));
      await tester.pump();
      return tester.takeException();
    }

    testWidgets('SCard / SChip / SectionTitle 2.5x da toshmaydi', (tester) async {
      expect(await pumpScaled(tester, const SCard(child: Text('Karta matni'))), isNull);
      expect(await pumpScaled(tester, const Center(child: SChip('Faol', color: Colors.teal))), isNull);
      expect(await pumpScaled(tester, const SectionTitle('Guruhlar')), isNull);
    });

    testWidgets('EmptyState / Loader 2.5x da toshmaydi', (tester) async {
      expect(await pumpScaled(tester, const EmptyState(text: 'Hech narsa topilmadi')), isNull);
      expect(await pumpScaled(tester, const Loader(label: 'Yuklanmoqda')), isNull);
    });

    testWidgets('ProgressBar / Ring / Avatar 2.5x da toshmaydi', (tester) async {
      expect(await pumpScaled(tester, const ProgressBar(0.5)), isNull);
      expect(await pumpScaled(tester, const Center(child: Ring(value: 50, center: Text('50')))), isNull);
      expect(await pumpScaled(tester, const Center(child: Avatar(name: 'Ali Valiyev'))), isNull);
      expect(tester.getSize(find.byType(Avatar)), const Size(48, 48));
    });

    testWidgets('SButton to\'liq kenglikda 2.5x da toshmaydi, balandligi 50 da qoladi',
        (tester) async {
      expect(await pumpScaled(tester, SButton('Saqlash', icon: Icons.save, onTap: () {})),
          isNull);
      // Balandlik qat'iy: shrift 2.5x kattalashsa ham 50px.
      expect(tester.getSize(find.byType(SButton)).height, 50);
    });

    // BUG-U5 (TUZATILDI) — SButton ichidagi `Row` da matn `Flexible`ga
    // o'ralmagan va `overflow`/`maxLines` berilmagan edi. Tor tugmada
    // (yonma-yon ikki tugma, sheet, tor karta) "RenderFlex overflowed ... on
    // the right" chiqardi; katta shrift buni tezlashtirardi.
    // Eski pin testlar o'chirildi.
    testWidgets(
      'BUG-U5 (shartnoma): tor tugmada matn qisqaradi (ellipsis), toshmaydi',
      (tester) async {
        final err = await pumpScaled(
          tester,
          Center(
            child: SizedBox(
              width: 120,
              child: SButton('Topshiriqni saqlash', icon: Icons.save, onTap: () {}),
            ),
          ),
          scale: 1.0,
        );
        expect(err, isNull);
        expect(find.byIcon(Icons.save), findsOneWidget);
        final text = tester.widget<Text>(find.text('Topshiriqni saqlash'));
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
        expect(tester.getSize(find.byType(SButton)).width, 120);
      },
    );

    testWidgets('BUG-U5 (shartnoma): 2.5x shriftda 160px tugma ham toshmaydi',
        (tester) async {
      final err = await pumpScaled(
        tester,
        Center(
          child: SizedBox(
            width: 160,
            child: SButton('Saqlash', icon: Icons.save, onTap: () {}),
          ),
        ),
      );
      expect(err, isNull);
    });

    testWidgets('BUG-U5: keng tugmada matn hamon to\'liq ko\'rinadi',
        (tester) async {
      final err = await pumpScaled(
        tester,
        Center(
          child: SizedBox(
            width: 320,
            child: SButton('Saqlash', icon: Icons.save, onTap: () {}),
          ),
        ),
        scale: 1.0,
      );
      expect(err, isNull);
      expect(find.text('Saqlash'), findsOneWidget);
    });

    // BUG-U5 (davomi) — GradeBox 30x30 QAT'IY va matn `textScaler` bilan
    // kattayadi (14px → 35px). Istisno OTILMAYDI: RenderParagraph jimgina
    // kesadi, ya'ni foydalanuvchi baho raqamini yarim ko'radi.
    testWidgets('BUG-U5: GradeBox 2.5x da ham 30x30, matn kesiladi',
        (tester) async {
      expect(await pumpScaled(tester, const Center(child: GradeBox(5))), isNull);
      expect(tester.getSize(find.byType(GradeBox)), const Size(30, 30));
      // Matn qutiga "qisilgan" — o'z tabiiy o'lchamidan kichik.
      expect(tester.getSize(find.text('5')).height, lessThanOrEqualTo(30));

      // Tabiiy (cheklovsiz) o'lcham 2.5x da 30px dan katta ekanini ko'rsatamiz.
      await tester.pumpWidget(wrap(
        const Center(
          child: Text('5', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        textScale: 2.5,
      ));
      expect(tester.getSize(find.text('5')).height, greaterThan(30));
    });
  });

  // -------------------------------------------------------------------------
  // 13. Ekran yordamchilari — sof funksiyalar (P1-11, P1-12, P2)
  // -------------------------------------------------------------------------
  //
  // Bu ekranlar uchun alohida test fayli yo'q, kirishni tekshirish mantiqi esa
  // aynan foydalanuvchi ma'lumotini yo'qotadigan joy edi — shuning uchun
  // yordamchilar top-level qilib chiqarildi va shu yerda qamrab olindi.
  group('P1-11 — parseScoreInput (topshiriq bali)', () {
    test('vergulli kasr QABUL qilinadi (o\'zbek/rus klaviaturasi)', () {
      expect(parseScoreInput('8,5'), 8.5);
      expect(parseScoreInput(' 8,5 '), 8.5);
      expect(parseScoreInput('0,5'), 0.5);
    });

    test('nuqtali kasr va butun son avvalgidek ishlaydi', () {
      expect(parseScoreInput('8.5'), 8.5);
      expect(parseScoreInput('10'), 10);
      expect(parseScoreInput('0'), 0);
    });

    test('yaroqsiz kirish null (jimgina "saqlandi" bo\'lmasin)', () {
      expect(parseScoreInput('abc'), isNull);
      expect(parseScoreInput(''), isNull);
      expect(parseScoreInput('   '), isNull);
      expect(parseScoreInput('8,5,5'), isNull);
      expect(parseScoreInput('NaN'), isNull);
      expect(parseScoreInput('Infinity'), isNull);
    });

    test('manfiy son PARSE qilinadi (chegara tekshiruvi chaqiruvchida)', () {
      expect(parseScoreInput('-10'), -10);
    });
  });

  group('P1-12 — parseMaxScoreInput (maksimal ball)', () {
    test('musbat son qabul qilinadi, vergul ham', () {
      expect(parseMaxScoreInput('100'), 100);
      expect(parseMaxScoreInput('7,5'), 7.5);
      expect(parseMaxScoreInput('7.5'), 7.5);
    });

    test('yaroqsiz matn 100 ga AYLANMAYDI — null', () {
      expect(parseMaxScoreInput('abc'), isNull);
      expect(parseMaxScoreInput(''), isNull);
      expect(parseMaxScoreInput('  '), isNull);
      expect(parseMaxScoreInput('1e400'), isNull, reason: 'cheksiz');
    });

    test('0 va manfiy qiymat rad etiladi', () {
      expect(parseMaxScoreInput('0'), isNull);
      expect(parseMaxScoreInput('-10'), isNull);
      expect(parseMaxScoreInput('-0,5'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 14. Xabarlar tabi — poller (P1-7, P1-8) va composer (U17)
  // -------------------------------------------------------------------------
  group('MessagesScreen — chat polleri', () {
    const msgJson = <String, Object?>{
      'id': 'm1',
      'className': 'G1',
      'senderUserId': 'u9',
      'senderName': 'Ali Valiyev',
      'senderRole': 'teacher',
      'text': 'Salom',
      'createdAt': '2026-03-12T10:00:00',
    };

    /// `dio` so'rovni nol uzunlikdagi taymer orqali yuboradi — shuning uchun
    /// javobni ko'rish uchun bir necha bo'sh kadr kerak.
    Future<void> flush(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(Duration.zero);
      }
    }

    /// Kanallar ro'yxatini ochib, "G1" suhbatiga kiradi.
    Future<FakeAdapter> openChat(
      WidgetTester tester, {
      GlobalKey<TickerHostState>? hostKey,
      Object? chatBody = const <Object?>[msgJson],
      Completer<void>? gate,
    }) async {
      final adapter = installFakeApi();
      // DIQQAT: "classes" birinchi yozilishi kerak — mos kelish substring bo'yicha.
      adapter.on('/teacher/chat/classes', body: <Object?>['G1']);
      adapter.on('/teacher/chat/', body: chatBody, gate: gate);
      // Tab ekranlari odatda qobiqning `Scaffold`i ichida yashaydi.
      await pumpScreen(
        tester,
        Scaffold(body: TickerHost(key: hostKey, child: const MessagesScreen())),
      );
      await flush(tester);
      await tester.tap(find.text('G1'));
      await tester.pump();
      await flush(tester);
      return adapter;
    }

    /// Bir "tick" (4 s) o'tkazib, javobni ham qayta ishlashga ulguradi.
    Future<void> tick(WidgetTester tester, {int times = 1}) async {
      for (var i = 0; i < times; i++) {
        await tester.pump(const Duration(seconds: 4));
        await flush(tester);
      }
    }

    testWidgets('P1-7: server bir xil xabarni qayta yuborsa TAKRORLANMAYDI',
        (tester) async {
      await openChat(tester);
      expect(find.text('Salom'), findsOneWidget);

      // Server `since` ni e'tiborsiz qoldirib, aynan o'sha xabarni qaytaraveradi.
      await tick(tester, times: 3);
      expect(find.text('Salom'), findsOneWidget,
          reason: 'id bo\'yicha dedupe bo\'lishi kerak');

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P1-7: oldingi so\'rov tugamaguncha yangisi boshlanmaydi',
        (tester) async {
      final gate = Completer<void>();
      final adapter = await openChat(tester, gate: gate);
      expect(adapter.countOf('/teacher/chat/G1'), 1);

      // Sekin tarmoq: 12 soniya ichida taymer 3 marta ishlaydi.
      await tick(tester, times: 3);
      expect(adapter.countOf('/teacher/chat/G1'), 1,
          reason: 'in-flight qorovuli so\'rovlarni to\'plab yubormasligi kerak');

      gate.complete();
      await flush(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P1-8: boshqa tabga o\'tilganda poller to\'xtaydi',
        (tester) async {
      final key = GlobalKey<TickerHostState>();
      final adapter = await openChat(tester, hostKey: key);
      final base = adapter.countOf('/teacher/chat/G1');

      await tick(tester);
      expect(adapter.countOf('/teacher/chat/G1'), base + 1);

      // Qobiqda boshqa tab tanlandi (IndexedStack tabni dispose QILMAYDI).
      key.currentState!.setEnabled(false);
      await tester.pump();
      final stopped = adapter.countOf('/teacher/chat/G1');
      await tick(tester, times: 3);
      expect(adapter.countOf('/teacher/chat/G1'), stopped,
          reason: 'ko\'rinmayotgan tab so\'rov yubormasligi kerak');

      // Tabga qaytilsa — davom etadi.
      key.currentState!.setEnabled(true);
      await tester.pump();
      await tick(tester);
      expect(adapter.countOf('/teacher/chat/G1'), greaterThan(stopped));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('P1-8: ilova fonga tushganda poller to\'xtaydi', (tester) async {
      final adapter = await openChat(tester);
      await tick(tester);
      final base = adapter.countOf('/teacher/chat/G1');

      // Holatlar ketma-ketligi qonuniy bo'lishi shart (resumed → … → paused).
      for (final s in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await flush(tester);
      await tick(tester, times: 3);
      expect(adapter.countOf('/teacher/chat/G1'), base,
          reason: 'fonda soatiga ~900 so\'rov ketmasligi kerak');

      // Qaytganda darhol bir marta yangilanadi.
      for (final s in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await flush(tester);
      expect(adapter.countOf('/teacher/chat/G1'), greaterThan(base));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('U17: yuborish javobi yozilayotgan yangi matnni o\'chirmaydi',
        (tester) async {
      final gate = Completer<void>();
      await openChat(tester);

      // Endi javoblarni "eshik" ortida ushlab turamiz (yuborish sekin ketadi).
      final adapter = installFakeApi();
      adapter.on('/teacher/chat/classes', body: <Object?>['G1']);
      adapter.on('/teacher/chat/', body: msgJson, gate: gate);

      await tester.enterText(find.byType(TextField), 'birinchi');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(Duration.zero);

      // Matn `await`dan OLDIN tozalanadi.
      expect(find.text('birinchi'), findsNothing);

      // Javob kelguncha foydalanuvchi yangi matn yozdi.
      await tester.enterText(find.byType(TextField), 'ikkinchi');
      await tester.pump();

      gate.complete();
      await flush(tester);

      expect(find.text('ikkinchi'), findsOneWidget,
          reason: 'javob kelganda yangi matn o\'chib ketmasligi kerak');

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P2 — resolveFileUrl (shartnoma PDF manzili)', () {
    test('boshida "/" bo\'lmagan nisbiy manzil TO\'G\'RI ulanadi', () {
      final u = resolveFileUrl('uploads/x.pdf');
      expect(u, isNotNull);
      expect(u.toString(), '$kFileBaseUrl/uploads/x.pdf');
      expect(u.toString(), isNot(contains('uzuploads')));
      expect(u!.path, '/uploads/x.pdf');
    });

    test('boshida "/" bor manzil ham bir xil natija beradi', () {
      expect(resolveFileUrl('/uploads/x.pdf').toString(), '$kFileBaseUrl/uploads/x.pdf');
      expect(resolveFileUrl('/uploads/x.pdf'), resolveFileUrl('uploads/x.pdf'));
    });

    test('to\'liq http manzil o\'zgarishsiz qoladi', () {
      expect(resolveFileUrl('https://cdn.example.uz/a.pdf').toString(),
          'https://cdn.example.uz/a.pdf');
    });

    test('bo\'sh manzil null', () {
      expect(resolveFileUrl(''), isNull);
      expect(resolveFileUrl('   '), isNull);
    });
  });
}
