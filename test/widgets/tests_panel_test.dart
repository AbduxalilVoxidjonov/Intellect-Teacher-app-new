// «Testlar» paneli (`group_tests_panel.dart`) va «Reyting» tabi
// (`group_rating_tab.dart`) uchun widget/integration testlari.
//
// QA hisobotidagi (3- va 4-bo'lim) nosozliklar TUZATILGANDAN keyin yozilgan —
// har bir test tuzatilgan xulqni QULFLAYDI, ya'ni regressiya bo'lsa qizaradi.
// Test nomi oldida QA identifikatori turadi (P1-1, P1-2, ...).
//
// Ekran o'lchami 1400×2400 (dpr 1.0) — jadvallar keng (`screen_harness.dart`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/models/models.dart';
import 'package:teacher/screens/group_rating_tab.dart';
import 'package:teacher/screens/group_tests_panel.dart';

import 'screen_harness.dart';

/* ================================================================== *
 *  Fixture yasovchilar — testlar
 * ================================================================== */

Map<String, dynamic> _scoreRow(
  String id,
  String name, {
  double? score,
  int rank = 0,
  String source = '',
  String answers = '',
  String submittedAt = '',
}) =>
    <String, dynamic>{
      'studentId': id,
      'fullName': name,
      'score': score,
      'rank': rank,
      'answers': answers,
      'submittedAt': submittedAt,
      'source': source,
    };

Map<String, dynamic> _online({
  String mode = 'online',
  String pdfUrl = '/uploads/test.pdf',
  String pdfName = 'test.pdf',
  int questionCount = 3,
  int optionCount = 4,
  String answerKey = 'ABC',
  String startAt = '2026-03-10T09:00',
  String endAt = '2026-03-10T11:00',
}) =>
    <String, dynamic>{
      'mode': mode,
      'pdfUrl': pdfUrl,
      'pdfName': pdfName,
      'questionCount': questionCount,
      'optionCount': optionCount,
      'answerKey': answerKey,
      'startAt': startAt,
      'endAt': endAt,
    };

Map<String, dynamic> _testDetail({
  double maxScore = 100,
  List<Map<String, dynamic>> rows = const [],
  Map<String, dynamic>? online,
}) =>
    <String, dynamic>{
      'id': 't1',
      'groupId': 'g1',
      'groupName': 'Ingliz A1',
      'name': 'Nazorat ishi',
      'date': '2026-03-10',
      'maxScore': maxScore,
      'createdAt': '2026-03-01T10:00',
      'createdBy': 'A. Voxidjonov',
      'rows': rows,
      if (online != null) 'online': online,
    };

Map<String, dynamic> _testCard({
  String id = 't1',
  String name = 'Nazorat ishi',
  double maxScore = 100,
  int studentCount = 2,
  int scoredCount = 1,
  double? avgScore,
  Map<String, dynamic>? online,
  int submittedCount = 0,
}) =>
    <String, dynamic>{
      'id': id,
      'groupId': 'g1',
      'name': name,
      'date': '2026-03-10',
      'maxScore': maxScore,
      'createdAt': '2026-03-01T10:00',
      'createdBy': 'A. Voxidjonov',
      'studentCount': studentCount,
      'scoredCount': scoredCount,
      'avgScore': avgScore,
      if (online != null) 'online': online,
      'submittedCount': submittedCount,
    };

/* ================================================================== *
 *  Fixture yasovchilar — reyting (jurnal + baholash jadvali)
 * ================================================================== */

Map<String, dynamic> _journalStudent(
  String id,
  String name, {
  String status = 'active',
}) =>
    <String, dynamic>{
      'studentId': id,
      'fullName': name,
      'status': status,
      'activatedAt': '2026-01-01',
      'balance': 0,
      'memberStart': '2026-01-01',
      'presentDefaultFrom': '',
      'frozenAt': status == 'frozen' ? '2026-03-01' : '',
      'debtMonths': 0,
    };

Map<String, dynamic> _journalEntry(String studentId, String date, int grade) =>
    <String, dynamic>{
      'studentId': studentId,
      'date': date,
      'period': 1,
      'grade': grade,
      'reasonId': null,
      'homework': null,
      'behavior': null,
      'mastery': null,
      'present': true,
    };

Map<String, dynamic> _journal({
  String month = '2026-03',
  List<String> columns = const [],
  List<Map<String, dynamic>> students = const [],
  List<Map<String, dynamic>> entries = const [],
}) =>
    <String, dynamic>{
      'group': <String, dynamic>{
        'id': 'g1',
        'name': 'Ingliz A1',
        'courseId': 'course-1',
        'courseName': 'Ingliz tili',
        'teacherName': 'A. Voxidjonov',
        'days': [0, 2],
        'startTime': '09:00',
        'endTime': '10:30',
        'room': 'Xona-1',
        'startDate': '2026-01-01',
        'monthlyFee': 500000,
      },
      'months': ['2026-03'],
      'month': month,
      'columns': [
        for (final d in columns) {'date': d, 'period': 1}
      ],
      'students': students,
      'entries': entries,
      'conductedDates': columns,
      'reschedules': const <Object>[],
    };

Map<String, dynamic> _board({
  String month = '2026-03',
  List<String> dates = const [],
  List<Map<String, dynamic>> criteria = const [],
  List<Map<String, dynamic>> students = const [],
}) =>
    <String, dynamic>{
      'groupId': 'g1',
      'groupName': 'Ingliz A1',
      'months': ['2026-03'],
      'month': month,
      'dates': dates,
      'criteria': criteria,
      'students': students,
    };

Map<String, dynamic> _criterion(String id, String name, [int order = 0]) =>
    <String, dynamic>{'id': id, 'name': name, 'order': order};

Map<String, dynamic> _boardStudent(String id, String name, List<String> doneKeys) =>
    <String, dynamic>{'studentId': id, 'fullName': name, 'doneKeys': doneKeys};

/* ================================================================== *
 *  Lokal yordamchilar (harness'da yo'q)
 * ================================================================== */

/// Reyting tabi o'zi scroll qilmaydi — chaqiruvchi sahifa beradi.
Widget _ratingHost({
  List<String> months = const ['2026-03'],
  String? defaultMonth = '2026-03',
}) =>
    Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: GroupRatingTab(
          groupId: 'g1',
          months: months,
          defaultMonth: defaultMonth,
        ),
      ),
    );

/// KPI kartaning QIYMATI (yorlig'i bo'yicha topiladi): `_Kpi` ichida
/// `Column[Row[Icon, Text(yorliq)], SizedBox, Text(qiymat)]` bor.
String _kpiValue(WidgetTester tester, String label) {
  final column = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  final texts = tester
      .widgetList<Text>(find.descendant(of: column, matching: find.byType(Text)))
      .toList();
  return texts.last.data ?? '';
}

/// Fokusni butunlay olib tashlash — TextField'ning "blur" hodisasini
/// (`_save`) ishga tushiradi.
Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  // `_save` — asinxron; navbatdagi mikrotasklar (dio) bajarilishi kerak.
  await tester.idle();
  await tester.pump();
}

/// Pull-to-refresh. Imo-ishora masofasi ekran o'lchamiga bog'liq bo'lgani uchun
/// `RefreshIndicator` to'g'ridan-to'g'ri ishga tushiriladi (aynan shu `onRefresh`
/// — ya'ni `_load` — chaqiriladi).
Future<void> _pullToRefresh(WidgetTester tester) async {
  final st = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
  unawaited(st.show());
  await tester.pump();
  await tester.idle();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter api;

  setUp(() {
    api = installFakeApi();
    // DIQQAT: `FakeAdapter` yo'lni `contains` bilan qidiradi va BIRINCHI mos
    // kelgani ishlaydi — shuning uchun `/scores` avval ro'yxatga olinadi.
    api.on('/teacher/test-results/t1/scores', body: _testDetail());
    api.on('/teacher/test-results/t1', body: _testDetail());
  });

  /* ================================================================ *
   *  group_tests_panel.dart — testlar ro'yxati
   * ================================================================ */

  group('GroupTestsPanel · ro\'yxat', () {
    testWidgets("sog'lom: testlar ro'yxati kartalar bilan chiqadi", (tester) async {
      api.on('/teacher/test-results', body: [
        _testCard(name: 'Nazorat ishi', scoredCount: 1, studentCount: 2, avgScore: 87.5),
        _testCard(
            id: 't2',
            name: 'Bot testi',
            scoredCount: 2,
            studentCount: 2,
            online: _online(),
            submittedCount: 2),
      ]);

      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: GroupTestsPanel(groupId: 'g1', title: 'Ingliz A1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nazorat ishi'), findsOneWidget);
      expect(find.text('Bot testi'), findsOneWidget);
      expect(find.text('ONLAYN'), findsOneWidget);
      expect(find.text('1/2 baholangan'), findsOneWidget);
      expect(find.text("O'rtacha: 87.5"), findsOneWidget);
    });
  });

  /* ================================================================ *
   *  TestDetailScreen — ball kiritish
   * ================================================================ */

  group('TestDetailScreen · ball kiritish', () {
    Widget detail() => const TestDetailScreen(testId: 't1', title: 'Nazorat ishi');

    testWidgets("sog'lom: o'quvchilar va ballari chiqadi, ball saqlanadi", (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1),
            _scoreRow('s2', 'Vali Aliyev'),
          ]));
      api.on('/teacher/test-results/t1/scores',
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1),
            _scoreRow('s2', 'Vali Aliyev', score: 55, rank: 2),
          ]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('80'), findsOneWidget); // s1 maydonidagi ball

      await tester.enterText(find.byType(TextField).at(1), '55');
      await _blur(tester);
      await tester.pumpAndSettle();

      final req = api.lastOf('/scores');
      expect(req, isNotNull);
      expect(req!.method, 'PUT');
      expect((req.data as Map)['studentId'], 's2');
      expect((req.data as Map)['score'], 55);
    });

    testWidgets(
        "P1-1: ro'yxatdan chiqib ketgan o'quvchining maydoni yiqilmaydi (\"Bad state: No element\")",
        (tester) async {
      // Boshida 2 o'quvchi; maydonga fokus qo'yamiz, keyin pull-to-refresh
      // faqat 1 o'quvchi qaytaradi. Eski kodda saqlanib qolgan `FocusNode`
      // "blur"da `_save('s2')` chaqirar va `firstWhere` `StateError` berardi.
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1),
            _scoreRow('s2', 'Vali Aliyev', score: 40, rank: 2),
          ]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();
      expect(find.text('Vali Aliyev'), findsOneWidget);

      await tester.tap(find.byType(TextField).at(1));
      await tester.pump();

      // Endi server s2 ni qaytarmaydi (o'chirilgan/muzlatilgan).
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [_scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1)]));

      await _pullToRefresh(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Vali Aliyev'), findsNothing);
      expect(find.text('Ali Valiyev'), findsOneWidget);
      // Yo'q bo'lgan o'quvchi uchun ball saqlash so'rovi KETMAGAN.
      expect(api.countOf('/scores'), 0);
    });

    testWidgets('P1-3: A saqlanayotganda B ning bali YO\'QOLMAYDI va bosib yozilmaydi',
        (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev'),
            _scoreRow('s2', 'Vali Aliyev'),
          ]));

      // A ning javobi "eshik"da ushlab turiladi va u B ning balini BILMAYDI.
      final gateA = Completer<void>();
      api.on('/teacher/test-results/t1/scores',
          gate: gateA,
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 10, rank: 1),
            _scoreRow('s2', 'Vali Aliyev'),
          ]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      // A ga 10, keyin fokus B ga o'tadi → A ning saqlashi BOSHLANADI (eshikda).
      await tester.enterText(find.byType(TextField).at(0), '10');
      await tester.enterText(find.byType(TextField).at(1), '20');
      await tester.pump();
      expect(api.countOf('/scores'), 1);

      // B ning javobi — alohida "eshik" va TO'G'RI qiymat bilan.
      final gateB = Completer<void>();
      api.on('/teacher/test-results/t1/scores',
          gate: gateB,
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 10, rank: 1),
            _scoreRow('s2', 'Vali Aliyev', score: 20, rank: 2),
          ]));

      await _blur(tester);
      await tester.pump();

      // (a) B ning saqlashi TASHLAB YUBORILMADI — ikkinchi so'rov ketdi.
      expect(api.countOf('/scores'), 2);
      final reqB = api.lastOf('/scores');
      expect((reqB!.data as Map)['studentId'], 's2');
      expect((reqB.data as Map)['score'], 20);

      // (b) A ning javobi kelganda B ning maydoni ESKI qiymat bilan
      //     bosib yozilmaydi (javobda s2 hali bo'sh).
      gateA.complete();
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '20');

      gateB.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '20');
    });

    testWidgets("U6: son bo'lmagan ball SABAB bilan rad etiladi", (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [_scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1)]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'abc');
      await _blur(tester);
      await tester.pump();

      expect(find.text("Ball faqat son bo'lishi kerak"), findsOneWidget);
      // Eski qiymat qaytariladi va server bezovta qilinmaydi.
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '80');
      expect(api.countOf('/scores'), 0);
    });

    testWidgets('U6: manfiy ball SABAB bilan rad etiladi', (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [_scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1)]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '-3');
      await _blur(tester);
      await tester.pump();

      expect(find.text("Ball 0 dan 100 gacha bo'lishi kerak"), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '80');
      expect(api.countOf('/scores'), 0);
    });

    testWidgets('U6: maksimal balldan katta qiymat ham rad etiladi', (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [_scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1)]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '150');
      await _blur(tester);
      await tester.pump();

      expect(find.text("Ball 0 dan 100 gacha bo'lishi kerak"), findsOneWidget);
      expect(api.countOf('/scores'), 0);
    });

    testWidgets("sog'lom: vergulli kasr ball qabul qilinadi (8,5 → 8.5)", (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [_scoreRow('s1', 'Ali Valiyev')]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '8,5');
      await _blur(tester);
      await tester.pumpAndSettle();

      expect((api.lastOf('/scores')!.data as Map)['score'], 8.5);
    });

    testWidgets('U3: pull-to-refresh ro\'yxatni spinnerga almashtirmaydi va yozilgan ballni saqlaydi',
        (tester) async {
      api.on('/teacher/test-results/t1',
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1),
            _scoreRow('s2', 'Vali Aliyev'),
          ]));

      await pumpScreen(tester, detail());
      await tester.pumpAndSettle();

      // s2 maydoniga yoziladi, LEKIN saqlanmaydi (fokus olinmaydi).
      await tester.enterText(find.byType(TextField).at(1), '42');
      await tester.pump();

      final gate = Completer<void>();
      api.on('/teacher/test-results/t1',
          gate: gate,
          body: _testDetail(rows: [
            _scoreRow('s1', 'Ali Valiyev', score: 80, rank: 1),
            _scoreRow('s2', 'Vali Aliyev'),
          ]));

      await _pullToRefresh(tester);

      // So'rov ketayotganda ro'yxat JOYIDA (butun ekran spinner emas).
      expect(find.text('Ali Valiyev'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      // Yozilgan, lekin saqlanmagan qiymat O'CHIRILMAYDI.
      expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text, '42');
    });
  });

  /* ================================================================ *
   *  TestFormSheet — test yaratish/tahrirlash
   * ================================================================ */

  group('TestFormSheet · onlayn test', () {
    GroupTest editing({int optionCount = 4, String startAt = '2026-03-10T09:00'}) => GroupTest(
          id: 't1',
          groupId: 'g1',
          name: 'Bot testi',
          date: '2026-03-10',
          maxScore: 3,
          createdAt: '2026-03-01T10:00',
          createdBy: 'A. Voxidjonov',
          studentCount: 2,
          scoredCount: 0,
          avgScore: null,
          submittedCount: 0,
          online: OnlineTest(
            mode: 'online',
            pdfUrl: '/uploads/test.pdf',
            pdfName: 'test.pdf',
            questionCount: 3,
            optionCount: optionCount,
            answerKey: 'ABC',
            startAt: startAt,
            endAt: '2026-03-10T11:00',
          ),
        );

    testWidgets('P1-2: optionCount 9 bo\'lsa ham tahrirlash oynasi OCHILADI', (tester) async {
      // Eski kodda `_options = 9` bo'lib qolar va `DropdownButton` assert'i
      // butun oynani yiqitardi.
      await pumpScreen(tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing(optionCount: 9))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Testni tahrirlash'), findsOneWidget);
      // 9 → 6 ga qisildi (dropdown bilgan eng katta qiymat).
      expect(find.text('A–F (6 ta)'), findsOneWidget);
    });

    testWidgets("P1-2: 2 dan kichik optionCount standart 4 ga (A–D) qaytadi", (tester) async {
      await pumpScreen(tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing(optionCount: 1))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('A–D (4 ta)'), findsOneWidget);
    });

    testWidgets("sog'lom: saqlangan optionCount (5) o'zgarmaydi", (tester) async {
      await pumpScreen(tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing(optionCount: 5))));
      await tester.pumpAndSettle();

      expect(find.text('A–E (5 ta)'), findsOneWidget);
    });

    testWidgets('N6: buzuq vaqt ("99:99") zaxira qiymatga tushadi', (tester) async {
      await pumpScreen(
          tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing(startAt: '2026-03-10T99:99'))));
      await tester.pumpAndSettle();

      expect(find.text('99:99'), findsNothing);
      expect(find.text('09:00'), findsOneWidget); // zaxira boshlanish vaqti
    });

    testWidgets("sog'lom: to'g'ri vaqt o'sha holicha ko'rsatiladi", (tester) async {
      await pumpScreen(
          tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing(startAt: '2026-03-10T14:35'))));
      await tester.pumpAndSettle();

      expect(find.text('14:35'), findsOneWidget);
    });

    testWidgets('U5: 200 dan katta savollar soni jimgina qisqartirilmaydi', (tester) async {
      await pumpScreen(tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing())));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Savollar soni'), '250');
      await tester.pumpAndSettle();

      expect(find.text("Savollar soni ko'pi bilan 200 ta bo'lishi mumkin"), findsOneWidget);
      // Maydonning O'ZI ham 200 ga tuzatiladi — kalit muharriri bilan mos bo'lsin.
      expect(find.widgetWithText(TextField, '200'), findsOneWidget);
    });

    testWidgets('U4: onlayndan oflaynga o\'tishda TASDIQ so\'raladi', (tester) async {
      await pumpScreen(tester, Scaffold(body: TestFormSheet(groupId: 'g1', editing: editing())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oflayn'));
      await tester.pumpAndSettle();

      expect(find.text("Oflaynga o'tkazilsinmi?"), findsOneWidget);

      // Bekor qilinsa — test ONLAYN bo'lib qoladi (fayl va kalit joyida).
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(find.text('test.pdf'), findsOneWidget);
      expect(find.text("TO'G'RI JAVOBLAR KALITI"), findsOneWidget);

      // Tasdiqlansa — oflayn rejimga o'tadi.
      await tester.tap(find.text('Oflayn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("O'tkazish"));
      await tester.pumpAndSettle();
      expect(find.text("TO'G'RI JAVOBLAR KALITI"), findsNothing);
    });
  });

  /* ================================================================ *
   *  group_rating_tab.dart — Reyting
   * ================================================================ */

  group('GroupRatingTab · reyting', () {
    testWidgets("sog'lom: jurnal + mezonlar yig'iladi va foiz to'g'ri", (tester) async {
      // 2 sana × 1 mezon = 2 ta imkoniyat. Ali 2/2 = 100%, Vali 1/2 = 50%.
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            students: [_journalStudent('s1', 'Ali Valiyev'), _journalStudent('s2', 'Vali Aliyev')],
            entries: [
              _journalEntry('s1', '2026-03-05', 5),
              _journalEntry('s2', '2026-03-05', 3),
            ],
          ));
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05', '2026-03-12'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const ['c1|2026-03-05', 'c1|2026-03-12']),
              _boardStudent('s2', 'Vali Aliyev', const ['c1|2026-03-05']),
            ],
          ));

      await pumpScreen(tester, _ratingHost());
      await tester.pumpAndSettle();

      expect(_kpiValue(tester, "Jami o'quvchi"), '2');
      expect(_kpiValue(tester, "O'rtacha"), '75%'); // (100 + 50) / 2
      expect(_kpiValue(tester, "To'liq bajarildi"), '1');
      expect(_kpiValue(tester, "Bo'sh"), '0');
      // Ali: jurnal 5 + bajarilgan 2 = 7; Vali: 3 + 1 = 4.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(topOf(tester, 'Ali Valiyev'), lessThan(topOf(tester, 'Vali Aliyev')));
    });

    testWidgets('P1-16: MUZLATILGAN o\'quvchi reytingga kirmaydi', (tester) async {
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            students: [
              _journalStudent('s1', 'Ali Valiyev'),
              _journalStudent('s2', 'Vali Aliyev', status: 'frozen'),
            ],
            entries: [_journalEntry('s1', '2026-03-05', 5)],
          ));
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              // Baholash jadvali muzlatilganni ham qaytaradi — filtr JURNAL
              // statusiga qarab ishlashi kerak (Jurnal/Davomat bilan bir xil).
              _boardStudent('s1', 'Ali Valiyev', const ['c1|2026-03-05']),
              _boardStudent('s2', 'Vali Aliyev', const []),
            ],
          ));

      await pumpScreen(tester, _ratingHost());
      await tester.pumpAndSettle();

      expect(find.text('Vali Aliyev'), findsNothing);
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(_kpiValue(tester, "Jami o'quvchi"), '1');
      // "Bo'sh" muzlatilgan o'quvchi hisobiga shishmaydi.
      expect(_kpiValue(tester, "Bo'sh"), '0');
      expect(_kpiValue(tester, "O'rtacha"), '100%');
    });

    testWidgets('P1-17: baholash yiqilsa OGOHLANTIRISH chiqadi, 0% emas', (tester) async {
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            students: [_journalStudent('s1', 'Ali Valiyev'), _journalStudent('s2', 'Vali Aliyev')],
            entries: [_journalEntry('s1', '2026-03-05', 5)],
          ));
      api.on('/teacher/grading/group', status: 500, body: {'message': 'board yiqildi'});

      await pumpScreen(tester, _ratingHost());
      await tester.pumpAndSettle();

      // (a) Ogohlantirish (qaysi OY yiqilgani bilan) + qayta urinish tugmasi.
      expect(find.text("Ma'lumot yuklanmadi (Mart 2026) — reyting to'liq emas."), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      // (b) Soxta "0%" ko'rsatilmaydi.
      expect(find.text('0%'), findsNothing);
      expect(_kpiValue(tester, "O'rtacha"), '—');
      expect(_kpiValue(tester, "To'liq bajarildi"), '—');
      expect(_kpiValue(tester, "Bo'sh"), '—');
      // (c) O'quvchilar baribir ko'rinadi (jurnal kelgan).
      expect(find.text('Ali Valiyev'), findsOneWidget);
    });

    testWidgets('P1-17: "Qayta urinish" bosilsa reyting to\'liq yuklanadi', (tester) async {
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            students: [_journalStudent('s1', 'Ali Valiyev')],
            entries: [_journalEntry('s1', '2026-03-05', 5)],
          ));
      api.on('/teacher/grading/group', status: 500, body: {'message': 'board yiqildi'});

      await pumpScreen(tester, _ratingHost());
      await tester.pumpAndSettle();
      expect(find.text('Qayta urinish'), findsOneWidget);

      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const ['c1|2026-03-05']),
            ],
          ));

      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();

      expect(find.text('Qayta urinish'), findsNothing);
      expect(_kpiValue(tester, "O'rtacha"), '100%');
    });

    testWidgets('N4: oy chipini bosish HISOB-KITOBNI qaytadan bajarmaydi (memoizatsiya)',
        (tester) async {
      // Ikkinchi oy tanlanganda faqat YANGI so'rovlar ketadi; hisob-kitob esa
      // `_load` ichida bir marta bajariladi (`build` da emas).
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            students: [_journalStudent('s1', 'Ali Valiyev')],
            entries: [_journalEntry('s1', '2026-03-05', 5)],
          ));
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const ['c1|2026-03-05']),
            ],
          ));

      await pumpScreen(tester, _ratingHost(months: const ['2026-02', '2026-03']));
      await tester.pumpAndSettle();

      final before = api.countOf('/teacher/journal/group');
      expect(before, 1);

      await tester.tap(find.text('Fevral 2026'));
      await tester.pumpAndSettle();

      // Ikki oy tanlandi → yana 2 ta jurnal so'rovi (har oyga bittadan).
      expect(api.countOf('/teacher/journal/group'), before + 2);
      expect(_kpiValue(tester, "Jami o'quvchi"), '1');
    });

    testWidgets("sog'lom: o'quvchi bo'lmasa bo'sh holat ko'rsatiladi", (tester) async {
      api.on('/teacher/journal/group', body: _journal());
      api.on('/teacher/grading/group', body: _board());

      await pumpScreen(tester, _ratingHost());
      await tester.pumpAndSettle();

      expect(find.text("Baholash mezonlari topilmadi yoki o'quvchi yo'q."), findsOneWidget);
    });
  });
}
