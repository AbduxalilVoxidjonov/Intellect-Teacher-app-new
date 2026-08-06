// Butun EKRANlarni soxta HTTP transporti ustida haydaydigan widget/integration
// testlari. Maqsad — `State` klasslari ichida yashiringan biznes-mantiqni
// (jurnal katagi rangi/belgisi, «Jami» ustuni, saralash, davomat foizi,
// baholash yig'indisi, login oqimi) bajariladigan test bilan QULFLASH.
//
// Har bir nosozlik uchun IKKI test bor:
//   1) `// BUG-Sn:` — HOZIRGI (noto'g'ri) xulqni qayd qiladi, doim yashil;
//   2) darhol keyingisi — KUTILGAN shartnoma, `skip:` bilan (tuzatilgach
//      `skip` olib tashlanadi va u yashil bo'lishi kerak).
//
// Ekran o'lchami 1400×2400 (dpr 1.0) — jadvallar keng bo'lgani uchun
// (qarang: `screen_harness.dart` → `pumpScreen`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/screens/group_detail_screen.dart';
import 'package:teacher/screens/group_grading_section.dart';
import 'package:teacher/screens/login_screen.dart';
import 'package:teacher/screens/salary_screen.dart';
import 'package:teacher/screens/tests_screen.dart';
import 'package:teacher/widgets/ui.dart';

import 'screen_harness.dart';

/* ================================================================== *
 *  Fixture yasovchilar
 * ================================================================== */

Map<String, dynamic> _group({
  String courseId = 'course-1',
  String startDate = '2026-01-01',
}) =>
    <String, dynamic>{
      'id': 'g1',
      'name': 'Ingliz A1',
      'courseId': courseId,
      'courseName': 'Ingliz tili',
      'teacherName': 'A. Voxidjonov',
      'days': [0, 2],
      'startTime': '09:00',
      'endTime': '10:30',
      'room': 'Xona-1',
      'startDate': startDate,
      'monthlyFee': 500000,
    };

Map<String, dynamic> _student(
  String id,
  String name, {
  String memberStart = '2026-01-01',
  String presentDefaultFrom = '',
  String status = 'active',
  double balance = 0,
  int debtMonths = 0,
  String photoUrl = '',
}) =>
    <String, dynamic>{
      'studentId': id,
      'fullName': name,
      'status': status,
      'activatedAt': '2026-01-01',
      'balance': balance,
      'memberStart': memberStart,
      'presentDefaultFrom': presentDefaultFrom,
      'frozenAt': '',
      'debtMonths': debtMonths,
      'photoUrl': photoUrl,
    };

Map<String, dynamic> _entry(
  String studentId,
  String date, {
  int? grade,
  String? reasonId,
  int? mastery,
  bool present = false,
}) =>
    <String, dynamic>{
      'studentId': studentId,
      'date': date,
      'period': 1,
      'grade': grade,
      'reasonId': reasonId,
      'homework': null,
      'behavior': null,
      'mastery': mastery,
      'present': present,
    };

Map<String, dynamic> _journal({
  String month = '2026-03',
  List<String> months = const ['2026-02', '2026-03'],
  List<String> columns = const [],
  List<Map<String, dynamic>> students = const [],
  List<Map<String, dynamic>> entries = const [],
  List<String> conducted = const [],
  String courseId = 'course-1',
  String startDate = '2026-01-01',
  List<Map<String, dynamic>> reschedules = const [],
}) =>
    <String, dynamic>{
      'group': _group(courseId: courseId, startDate: startDate),
      'months': months,
      'month': month,
      'columns': [for (final d in columns) {'date': d, 'period': 1}],
      'students': students,
      'entries': entries,
      'conductedDates': conducted,
      'reschedules': reschedules,
    };

Map<String, dynamic> _meta(List<Map<String, dynamic>> reasons) => <String, dynamic>{
      'quarters': const <Object>[],
      'absenceReasons': reasons,
      'currentQuarter': 1,
      'currentWeek': 1,
    };

Map<String, dynamic> _reason(String id, String name, String short, {bool isLate = false}) =>
    <String, dynamic>{'id': id, 'name': name, 'short': short, 'isLate': isLate};

Map<String, dynamic> _board({
  String month = '2026-03',
  List<String> months = const ['2026-03'],
  List<String> dates = const [],
  List<Map<String, dynamic>> criteria = const [],
  List<Map<String, dynamic>> students = const [],
}) =>
    <String, dynamic>{
      'groupId': 'g1',
      'groupName': 'Ingliz A1',
      'months': months,
      'month': month,
      'dates': dates,
      'criteria': criteria,
      'students': students,
    };

Map<String, dynamic> _criterion(String id, String name, [int order = 0]) =>
    <String, dynamic>{'id': id, 'name': name, 'order': order};

Map<String, dynamic> _boardStudent(String id, String name, List<String> doneKeys) =>
    <String, dynamic>{'studentId': id, 'fullName': name, 'doneKeys': doneKeys};

/// Boardsiz (yo'l ro'yxatidan tashqari) jurnalni oching — «Jami» faqat jurnal
/// baholaridan yig'iladi.
const _emptyBoard = <String, dynamic>{
  'groupId': 'g1',
  'groupName': 'Ingliz A1',
  'months': <String>[],
  'month': '2026-03',
  'dates': <String>[],
  'criteria': <Object>[],
  'students': <Object>[],
};

Widget get _detail => const GroupDetailScreen(groupId: 'g1', groupName: 'Ingliz A1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAdapter api;

  setUp(() {
    api = installFakeApi();
  });

  /* ================================================================ *
   *  group_detail_screen.dart — Jurnal jadvali
   * ================================================================ */

  group('GroupDetailScreen · jurnal', () {
    testWidgets(
        'BUG-S1 (TUZATILDI) shartnoma: sabab metasi yuklanmasa ham kelmagan o\'quvchi ✓ bo\'lmasligi kerak',
        (tester) async {
      api.on('/teacher/meta', status: 500, body: {'message': 'server yiqildi'});
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', reasonId: 'r-sick')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('✓'), findsNothing);
      // Sabab nomi noma'lum — lekin "kelmadi" fakti ko'rinadi.
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets(
        'BUG-S1 (TUZATILDI): sabab o\'chirilgan (meta bo\'sh) bo\'lsa ham kelmaganlik saqlanadi',
        (tester) async {
      // Ikkinchi trigger: hech qanday xato yo'q, shunchaki sabab Sozlamalardan
      // o'chirilgan → `reasonById` qidiruvi bo'sh qaytadi.
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', reasonId: 'o-chirilgan')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('✓'), findsNothing);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('BUG-S1 (TUZATILDI): meta yiqilsa ko\'rinadigan ogohlantirish chiqadi',
        (tester) async {
      api.on('/teacher/meta', status: 500, body: {'message': 'server yiqildi'});
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.textContaining('Davomat sabablari yuklanmadi'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    });

    testWidgets('sog\'lom: meta yuklansa o\'sha katak SABAB qisqartmasi bilan chiqadi', (tester) async {
      api.on('/teacher/meta', body: _meta([_reason('r-sick', 'Kasal', 'K')]));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', reasonId: 'r-sick')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('K'), findsOneWidget);
      expect(find.text('✓'), findsNothing);
    });

    testWidgets('sog\'lom: baholash jadvali kelganda «Jami» = jurnal + mezonlar va tartib to\'g\'ri',
        (tester) async {
      // Ali: jurnal 3+3=6, mezonlar 5 → 11. Vali: jurnal 4+4=8, mezon 0 → 8.
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05', '2026-03-12'],
            students: [_student('s1', 'Ali Valiyev'), _student('s2', 'Vali Aliyev')],
            entries: [
              _entry('s1', '2026-03-05', grade: 3),
              _entry('s1', '2026-03-12', grade: 3),
              _entry('s2', '2026-03-05', grade: 4),
              _entry('s2', '2026-03-12', grade: 4),
            ],
          ));
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const [
                'c1|2026-03-05',
                'c1|2026-03-06',
                'c1|2026-03-07',
                'c1|2026-03-08',
                'c1|2026-03-09',
              ]),
              _boardStudent('s2', 'Vali Aliyev', const []),
            ],
          ));

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('11'), findsOneWidget); // Ali «Jami»
      expect(find.text('8'), findsOneWidget); // Vali «Jami»
      // Kombinatsiyalangan yig'indi bo'yicha Ali BIRINCHI.
      expect(topOf(tester, 'Ali Valiyev'), lessThan(topOf(tester, 'Vali Aliyev')));
    });

    testWidgets(
        'BUG-S2 (TUZATILDI) shartnoma: baholash yuklanmaganda foydalanuvchi ogohlantirilishi kerak',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', grade: 3)],
          ));
      api.on('/teacher/grading/group', status: 500, body: {'message': 'board yiqildi'});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // «Jami» to'liq emasligi bildirilishi shart (snackbar / belgi / matn).
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BUG-S2 (TUZATILDI): board yiqilsa «Jami» 0/jurnal-only EMAS, «—» bo\'ladi',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05', '2026-03-12'],
            students: [_student('s1', 'Ali Valiyev'), _student('s2', 'Vali Aliyev')],
            entries: [
              _entry('s1', '2026-03-05', grade: 3),
              _entry('s1', '2026-03-12', grade: 3),
              _entry('s2', '2026-03-05', grade: 4),
              _entry('s2', '2026-03-12', grade: 4),
            ],
          ));
      api.on('/teacher/grading/group', status: 500, body: {'message': 'board yiqildi'});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // Jurnal-only yig'indi (6 / 8) ISHONCHLI raqam sifatida ko'rsatilmaydi.
      expect(find.text('6'), findsNothing);
      expect(find.text('8'), findsNothing);
      expect(find.text('—'), findsNWidgets(2)); // ikkala «Jami» ustuni
      // Ko'rinadigan ogohlantirish (banner) ham bor.
      expect(find.textContaining('Baholash jadvali yuklanmadi'), findsOneWidget);
    });

    testWidgets('BUG-S2 (TUZATILDI): `_reqId` tokeni — eski oyning baholashi yangisiga ulanmaydi',
        (tester) async {
      // Mart jurnali + Mart baholashi «eshik» ortida qoladi; foydalanuvchi
      // Fevralga o'tadi. Eshik ochilganda ESKI javob YANGI oy ustiga
      // yozilmasligi kerak (aks holda Ali'ning «Jami»si 5 → 10 bo'lardi).
      final gate = Completer<void>();
      api.on('/teacher/journal/group',
          body: _journal(
            month: '2026-03',
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', grade: 5)],
          ));
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const ['c1|2026-03-05']),
            ],
          ),
          gate: gate);

      await pumpScreen(tester, _detail);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Mart baholashi eshik ortida turibdi.
      expect(api.countOf('/teacher/grading/group'), 1);

      // Fevralga o'tamiz — jurnal ham, baholash ham YANGI javob beradi.
      api.on('/teacher/journal/group',
          body: _journal(
            month: '2026-02',
            columns: ['2026-02-05'],
            conducted: ['2026-02-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-02-05', grade: 5)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      await tester.tap(find.text('Fevral 2026'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      gate.complete();
      await tester.pumpAndSettle();

      // Fevral jurnali (5) + FEVRAL baholashi (eshikdan chiqqan Mart javobi EMAS).
      expect(find.text('5'), findsNWidgets(2)); // katak + «Jami»
      expect(find.text('10'), findsNothing);
      expect(find.text('6'), findsNothing);
    });

    testWidgets(
        'BUG-S3 (TUZATILDI): grid «·» chizgan darslar Davomatda "keldi" deb sanalmaydi',
        (tester) async {
      // presentDefaultFrom (2026-03-20) memberStart (2026-03-01) dan KEYIN:
      // `_cell` → present=false → «·»; `_attendanceRow` ham AYNI qoidani ishlatadi.
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05', '2026-03-12'],
            students: [
              _student('s1', 'Ali Valiyev',
                  memberStart: '2026-03-01', presentDefaultFrom: '2026-03-20'),
            ],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // Jurnal: ikkala katak ham "belgilanmagan" (·).
      expect(find.text('·'), findsNWidgets(2));

      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      // Hisobga olinadigan dars YO'Q — 2/2 · 100% emas.
      expect(find.text('100%'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('0'), findsNWidgets(2)); // DARS va KELDI ustunlari
    });

    testWidgets(
        'BUG-S3 (TUZATILDI): presentDefaultFrom\'dan oldin ANIQ belgilangan dars sanaladi',
        (tester) async {
      // Aniq "keldi (bor)" belgisi bo'lgan dars gridda ham ✓ chiziladi —
      // demak Davomatda ham hisobga olinishi SHART.
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05', '2026-03-12'],
            students: [
              _student('s1', 'Ali Valiyev',
                  memberStart: '2026-03-01', presentDefaultFrom: '2026-03-20'),
            ],
            entries: [_entry('s1', '2026-03-05', present: true)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('✓'), findsOneWidget);
      expect(find.text('·'), findsOneWidget);

      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      // «O'QUVCHILAR: 1» (info karta) + № + DARS + KELDI.
      expect(find.text('1'), findsNWidgets(4));
      expect(find.text('2'), findsNothing); // 2 dars sanalmaydi
    });

    testWidgets('BUG-S3 shartnoma: Jurnal va Davomat bir xil ma\'lumot ko\'rsatishi kerak',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05', '2026-03-12'],
            students: [
              _student('s1', 'Ali Valiyev',
                  memberStart: '2026-03-01', presentDefaultFrom: '2026-03-20'),
            ],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      // Jurnalda «·» bo'lgan darslar Davomatda 100% bo'lmasligi kerak.
      expect(find.text('100%'), findsNothing);
    }); // BUG-S3 (TUZATILDI)

    testWidgets('BUG-S4 (TUZATILDI) shartnoma: a\'zolikdan oldingi baho «Jami»ga qo\'shilmasligi kerak',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            students: [_student('s1', 'Ali Valiyev', memberStart: '2026-03-10')],
            entries: [_entry('s1', '2026-03-05', grade: 5)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('5'), findsNothing);
      expect(find.text('—'), findsOneWidget); // «Jami» = 0
    }); // BUG-S4 (TUZATILDI)

    testWidgets('BUG-S5 (TUZATILDI) shartnoma: kelmaganlik mastery ostida yo\'qolmasligi kerak',
        (tester) async {
      api.on('/teacher/meta', body: _meta([_reason('r-sick', 'Kasal', 'K')]));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', reasonId: 'r-sick', mastery: 2)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('K'), findsOneWidget);
      expect(find.text('🙋'), findsNothing);
    }); // BUG-S5 (TUZATILDI)

    testWidgets('BUG-S5 (TUZATILDI): varaqda sabab tanlansa «darsga munosabat» tozalanadi',
        (tester) async {
      api.on('/teacher/meta',
          body: _meta([
            _reason('r-sick', 'Kasal', 'K'),
            _reason('r-late', 'Kech qoldi', 'Kk', isLate: true),
          ]));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', mastery: 2)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // Katakni ochamiz — «Active» tanlangan holatda.
      await tester.tap(find.text('🙋'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      // «Kasal» (kech emas) tanlansa munosabat ham o'chadi.
      await tester.tap(find.text('Kasal'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);

      // «Kech qoldi» esa darsda qatnashgan — munosabat saqlanadi.
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kech qoldi'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('sog\'lom: «Jami» 0 bo\'lsa «—» chiziladi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05', '2026-03-12'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('sog\'lom: faol o\'quvchi bo\'lmasa bo\'sh holat', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(columns: ['2026-03-05'], students: const []));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text("Bu guruhda faol o'quvchi yo'q."), findsOneWidget);
    });

    testWidgets('sog\'lom: muzlatilgan o\'quvchi ro\'yxatdan chiqariladi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            students: [_student('s1', 'Muz Muzov', status: 'frozen')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('Muz Muzov'), findsNothing);
      expect(find.text("Bu guruhda faol o'quvchi yo'q."), findsOneWidget);
    });

    testWidgets('sog\'lom: ustunlar bo\'sh bo\'lsa «dars to\'g\'ri kelmadi» holati', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(columns: const [], students: [_student('s1', 'Ali Valiyev')]));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.textContaining("dars to'g'ri kelmadi"), findsOneWidget);
    });

    testWidgets('sog\'lom: kurs biriktirilmagan bo\'lsa jurnal yuritilmaydi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            courseId: '',
            columns: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text("Guruhga kurs biriktirilmagan — jurnal yuritib bo'lmaydi."),
          findsOneWidget);
    });

    testWidgets('sog\'lom: jurnal so\'rovi yiqilsa xato holati ko\'rsatiladi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group', status: 500, body: {'message': 'Jurnal yiqildi'});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('U2 (TUZATILDI): bitta muvaffaqiyatsiz yangilash yuklangan jurnalni yo\'qotmaydi',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      expect(find.text('Ali Valiyev'), findsOneWidget);

      // Endi yangilash yiqiladi (tabga qayta bosish `_load` ni chaqiradi).
      api.on('/teacher/journal/group', status: 500, body: {'message': 'Jurnal yiqildi'});
      await tester.tap(find.text('Jurnal'));
      await tester.pumpAndSettle();

      // Jadval joyida qoladi, xato esa toast bo'lib chiqadi.
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('C2 (TUZATILDI): saqlash tugamasdan ekran yopilsa `setState` xatosi bo\'lmaydi',
        (tester) async {
      final gate = Completer<void>();
      api.on('/teacher/meta', body: _meta(const []));
      // DIQQAT: `/teacher/journal/group` `/teacher/journal` dan OLDIN yoziladi —
      // FakeAdapter birinchi mos kelgan yo'lni oladi.
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      api.on('/teacher/journal', body: const <String, Object?>{}, gate: gate);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('✓')); // katakni ochish
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saqlash'));
      // `_saving` overlay'i cheksiz aylanadi — `pumpAndSettle` o'rniga qadamlab.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(api.lastOf('/teacher/journal')!.method, 'PUT');

      // Saqlash ketayotganda ORQAGA bosildi → ekran dispose bo'ldi.
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('R2 (TUZATILDI): ommaviy davomat hali qo\'shilmagan o\'quvchiga yozilmaydi',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [
              _student('s1', 'Ali Valiyev'),
              _student('s2', 'Yangi Yangiyev', memberStart: '2026-03-10'),
            ],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      api.on('/teacher/journal/bulk-attendance', body: const <String, Object?>{});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('05')); // sarlavha sanasi → ommaviy varaq
      await tester.pumpAndSettle();

      // Varaq matni ham FILTRLANGAN sonni ko'rsatadi.
      expect(find.textContaining("1 o'quvchiga birdan"), findsOneWidget);

      await tester.tap(find.text('✓ Hammasi keldi'));
      await tester.pumpAndSettle();

      final data = api.lastOf('/teacher/journal/bulk-attendance')!.data! as Map;
      expect(data['studentIds'], <String>['s1']);
      expect(data['absent'], isFalse);
    });

    testWidgets('R3 (TUZATILDI): sanalar solishtirishdan oldin "yyyy-MM-dd" ga qisqartiriladi',
        (tester) async {
      // Server bir joyda `2026-03-05`, boshqasida `2026-03-05T09:00:00` beradi.
      // Ilgari a'zolik BOSHLANGAN kun «berk» katak bo'lib qolardi va bahosi
      // katakda ko'rinmasdi.
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev', memberStart: '2026-03-05T00:00:00')],
            entries: [_entry('s1', '2026-03-05T09:00:00', grade: 4)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // Katakda ham, «Jami» ustunida ham 4.
      expect(find.text('4'), findsNWidgets(2));
      expect(find.text('—'), findsNothing);
    });

    testWidgets('U1 (TUZATILDI): «Tozalash» tasdiqsiz o\'chirmaydi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [_entry('s1', '2026-03-05', mastery: 2)],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      api.on('/teacher/journal', body: const <String, Object?>{});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🙋'));
      await tester.pumpAndSettle();

      // 1) Tasdiq oynasi ochiladi va BEKOR qilinsa hech nima o'chmaydi.
      await tester.tap(find.widgetWithText(SButton, 'Tozalash'));
      await tester.pumpAndSettle();
      expect(find.text("Ha, o'chirilsin"), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(api.requests.any((r) => r.method == 'DELETE'), isFalse);

      // 2) Tasdiqlansa — DELETE ketadi.
      await tester.tap(find.widgetWithText(SButton, 'Tozalash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ha, o'chirilsin"));
      await tester.pumpAndSettle();
      expect(api.requests.any((r) => r.method == 'DELETE'), isTrue);
    });

    testWidgets('U1 (TUZATILDI): «✗ Hammasi kelmadi» tasdiq so\'raydi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      api.on('/teacher/journal/bulk-attendance', body: const <String, Object?>{});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('✗ Hammasi kelmadi'));
      await tester.pumpAndSettle();

      expect(find.text('Ha, belgilansin'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(api.countOf('/teacher/journal/bulk-attendance'), 0);

      await tester.tap(find.text('✗ Hammasi kelmadi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ha, belgilansin'));
      await tester.pumpAndSettle();

      expect(api.countOf('/teacher/journal/bulk-attendance'), 1);
      expect((api.lastOf('/teacher/journal/bulk-attendance')!.data! as Map)['absent'], isTrue);
    });

    testWidgets('U1 (TUZATILDI): «Asl kuniga qaytarish» tasdiq so\'raydi', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-05'],
            conducted: ['2026-03-05'],
            students: [_student('s1', 'Ali Valiyev')],
            reschedules: [
              {'id': 'rs1', 'fromDate': '2026-03-03', 'toDate': '2026-03-05', 'time': '09:00'},
            ],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);
      api.on('/teacher/journal/reschedule', body: const <String, Object?>{});

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asl kuniga qaytarish'));
      await tester.pumpAndSettle();

      expect(find.text('Ha, qaytarilsin'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(api.countOf('/teacher/journal/reschedule'), 0);

      await tester.tap(find.text('Asl kuniga qaytarish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ha, qaytarilsin'));
      await tester.pumpAndSettle();

      expect(api.countOf('/teacher/journal/reschedule'), 1);
    });
  });

  /* ================================================================ *
   *  group_detail_screen.dart — Davomat tabi
   * ================================================================ */

  group('GroupDetailScreen · davomat', () {
    testWidgets('sog\'lom: KECH QOLDI sabablari foizga qo\'shilmaydi', (tester) async {
      // 5 dars: 1 ta sababli kelmagan (kech emas) + 1 ta kech qolgan →
      // keldi = 4, foiz = 80%. Kech qolgani ham sanalsa 60% bo'lardi.
      api.on('/teacher/meta',
          body: _meta([
            _reason('r-sick', 'Kasal', 'K'),
            _reason('r-late', 'Kech qoldi', 'Kk', isLate: true),
          ]));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-02', '2026-03-04', '2026-03-09', '2026-03-11', '2026-03-16'],
            conducted: ['2026-03-02', '2026-03-04', '2026-03-09', '2026-03-11', '2026-03-16'],
            students: [_student('s1', 'Ali Valiyev')],
            entries: [
              _entry('s1', '2026-03-02', reasonId: 'r-sick'),
              _entry('s1', '2026-03-04', reasonId: 'r-late'),
            ],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget); // DARS
      expect(find.text('4'), findsOneWidget); // KELDI
      expect(find.text('80%'), findsOneWidget); // DAVOMAT
    });

    testWidgets('sog\'lom: memberStart\'dan oldingi darslar o\'quvchi hisobiga kirmaydi',
        (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-02', '2026-03-04', '2026-03-09'],
            conducted: ['2026-03-02', '2026-03-04', '2026-03-09'],
            students: [_student('s1', 'Ali Valiyev', memberStart: '2026-03-04')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      // 3 emas, 2 dars sanaladi.
      expect(find.text('2'), findsNWidgets(2)); // DARS va KELDI
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('sog\'lom: o\'tilgan dars bo\'lmasa bo\'sh holat', (tester) async {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(
            columns: ['2026-03-02'],
            conducted: const [],
            students: [_student('s1', 'Ali Valiyev')],
          ));
      api.on('/teacher/grading/group', body: _emptyBoard);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Davomat'));
      await tester.pumpAndSettle();

      expect(find.textContaining("o'tilgan dars yo'q"), findsOneWidget);
    });
  });

  /* ================================================================ *
   *  group_grading_section.dart
   * ================================================================ */

  group('GroupGradingSection', () {
    Widget wrap() => Scaffold(
          body: SingleChildScrollView(
            child: const GroupGradingSection(groupId: 'g1', initialMonth: '2026-03'),
          ),
        );

    testWidgets('sog\'lom: oy chiplari, sana tasmasi, yig\'indi chipi va o\'quvchi foizi',
        (tester) async {
      // 2 sana × 2 mezon = 4 belgi/o'quvchi; 1 o'quvchi 3 tasini bajargan.
      api.on('/teacher/grading/group',
          body: _board(
            months: const ['2026-02', '2026-03'],
            dates: const ['2026-03-05', '2026-03-12'],
            criteria: [_criterion('c1', 'Uy vazifasi'), _criterion('c2', 'Faollik')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const [
                'c1|2026-03-05',
                'c2|2026-03-05',
                'c1|2026-03-12',
              ]),
            ],
          ));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      // Oy chiplari.
      expect(find.text('Fevral 2026'), findsOneWidget);
      expect(find.text('Mart 2026'), findsOneWidget);
      // Sana tasmasi (kun raqami + hafta kuni).
      expect(find.text('05'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      // Yig'indi chipi.
      expect(find.text('3 / 4 · 75%'), findsOneWidget);
      // Har o'quvchi yonidagi yorliq.
      expect(find.text('3/4 · 75%'), findsOneWidget);
      // Mezon sarlavhalari + «Jami».
      expect(find.text('Uy vazifasi'), findsOneWidget);
      expect(find.text('Faollik'), findsOneWidget);
      expect(find.text('Jami'), findsOneWidget);
    });

    testWidgets('sog\'lom: sana almashtirilsa kunlik «Jami» qayta hisoblanadi', (tester) async {
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05', '2026-03-12'],
            criteria: [_criterion('c1', 'Uy vazifasi'), _criterion('c2', 'Faollik')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const [
                'c1|2026-03-05',
                'c2|2026-03-05',
                'c1|2026-03-12',
              ]),
            ],
          ));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      // Boshlanishida oxirgi sana (12-mart) tanlanadi → kunlik jami = 1.
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();

      // 5-mart → ikkala mezon ham bajarilgan → 2.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('BUG-S6 (TUZATILDI) shartnoma: `done` hech qachon `total`dan oshmasligi kerak',
        (tester) async {
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05', '2026-03-12', '2026-03-19'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: [
              _boardStudent('s1', 'Ali Valiyev', const [
                'c1|2026-03-05',
                'c1|2026-03-12',
                'c1|2026-03-19',
                'c1|2026-03-26',
              ]),
            ],
          ));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      expect(find.text('3 / 3 · 100%'), findsOneWidget);
      expect(find.text('3/3 · 100%'), findsOneWidget);
    }); // BUG-S6 (TUZATILDI)

    testWidgets('sog\'lom: mezon biriktirilmagan bo\'lsa jadval umuman chizilmaydi', (tester) async {
      api.on('/teacher/grading/group',
          body: _board(dates: const ['2026-03-05'], criteria: const []));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Baholash mezoni biriktirilmagan.'), findsOneWidget);
      expect(find.text('Jami'), findsNothing);
    });

    testWidgets('sog\'lom: dars kuni bo\'lmasa «dars kuni yo\'q» holati', (tester) async {
      api.on('/teacher/grading/group',
          body: _board(dates: const [], criteria: [_criterion('c1', 'Uy vazifasi')]));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      expect(find.text("Mart 2026 oyida dars kuni yo'q."), findsOneWidget);
    });

    testWidgets('sog\'lom: total=0 (o\'quvchi yo\'q) — yig\'indi kartasi yo\'q, yiqilmaydi',
        (tester) async {
      api.on('/teacher/grading/group',
          body: _board(
            dates: const ['2026-03-05'],
            criteria: [_criterion('c1', 'Uy vazifasi')],
            students: const [],
          ));

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      expect(find.text("Guruhda faol o'quvchi yo'q."), findsOneWidget);
      expect(find.textContaining('·'), findsNothing); // yig'indi chipi yo'q
      expect(tester.takeException(), isNull);
    });

    testWidgets('sog\'lom: board yiqilsa xato holati ko\'rsatiladi', (tester) async {
      api.on('/teacher/grading/group', status: 500, body: {'message': 'Board yiqildi'});

      await pumpScreen(tester, wrap());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  /* ================================================================ *
   *  login_screen.dart
   * ================================================================ */

  group('LoginScreen', () {
    testWidgets('sog\'lom: parol maydoni yopiq, ko\'z tugmasi ochadi', (tester) async {
      await pumpScreen(tester, const LoginScreen());
      await tester.pumpAndSettle();

      TextField passwordField() =>
          tester.widget<TextField>(find.byType(TextField).last);

      expect(passwordField().obscureText, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField).first).obscureText, isFalse);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(passwordField().obscureText, isFalse);
    });

    testWidgets('sog\'lom: so\'rov ketayotganda tugma o\'chadi va ikkinchi POST ketmaydi',
        (tester) async {
      final gate = Completer<void>();
      api.on('/auth/login',
          status: 400, body: {'message': 'Login yoki parol xato'}, gate: gate);

      await pumpScreen(tester, const LoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'ustoz@intellect.uz');
      await tester.enterText(find.byType(TextField).last, 'parol123');
      await tester.tap(find.text('Kirish'));
      await tester.pump();

      expect(tester.widget<SButton>(find.byType(SButton)).loading, isTrue);
      expect(find.text('Kirish'), findsNothing); // matn o'rnida spinner

      // dio quvuri Timer(0) ishlatadi — soatni bir oz surib so'rovni chiqaramiz.
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.countOf('/auth/login'), 1);

      // Ikkinchi bosish — hech narsa yubormasligi kerak.
      await tester.tap(find.byType(SButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.countOf('/auth/login'), 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(api.countOf('/auth/login'), 1);
      expect(find.text('Kirish'), findsOneWidget);
    });

    testWidgets('sog\'lom: serverning xato xabari ekranda chiqadi', (tester) async {
      api.on('/auth/login', status: 400, body: {'message': 'Login yoki parol xato'});

      await pumpScreen(tester, const LoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'ustoz@intellect.uz');
      await tester.enterText(find.byType(TextField).last, 'xato');
      await tester.tap(find.text('Kirish'));
      await tester.pumpAndSettle();

      expect(find.text('Login yoki parol xato'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('BUG-S7 (TUZATILDI) shartnoma: bo\'sh maydonlar bilan so\'rov yuborilmasligi kerak',
        (tester) async {
      api.on('/auth/login', status: 400, body: {'message': "Login yoki parol noto'g'ri"});

      await pumpScreen(tester, const LoginScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kirish'));
      await tester.pumpAndSettle();

      expect(api.countOf('/auth/login'), 0);
    });

    testWidgets('BUG-S7 (TUZATILDI): bo\'sh maydonda tushunarli mahalliy xabar chiqadi',
        (tester) async {
      api.on('/auth/login', status: 400, body: {'message': "Login yoki parol noto'g'ri"});

      await pumpScreen(tester, const LoginScreen());
      await tester.pumpAndSettle();

      // Faqat login kiritilgan — parol bo'sh.
      await tester.enterText(find.byType(TextField).first, 'ustoz@intellect.uz');
      await tester.tap(find.text('Kirish'));
      await tester.pumpAndSettle();

      expect(find.text('Login va parolni kiriting'), findsOneWidget);
      expect(find.text("Login yoki parol noto'g'ri"), findsNothing);
      expect(api.countOf('/auth/login'), 0);
    });
  });

  /* ================================================================ *
   *  tests_screen.dart / salary_screen.dart (qo'shimcha qamrov)
   * ================================================================ */

  group('TestsScreen', () {
    testWidgets('sog\'lom: guruhlar ro\'yxati chiqadi', (tester) async {
      api.on('/teacher/classes', body: [
        {
          'classId': 'g1',
          'className': 'Ingliz A1',
          'subjects': [
            {'id': 'c1', 'name': 'Ingliz tili'}
          ],
        },
      ]);

      await pumpScreen(tester, const TestsScreen(showBack: true));
      await tester.pumpAndSettle();

      expect(find.text('Guruhni tanlang'), findsOneWidget);
      expect(find.text('Ingliz A1'), findsOneWidget);
    });

    testWidgets('sog\'lom: guruh yo\'q bo\'lsa bo\'sh holat', (tester) async {
      api.on('/teacher/classes', body: const <Object>[]);

      await pumpScreen(tester, const TestsScreen(showBack: true));
      await tester.pumpAndSettle();

      expect(find.text("Sizga biriktirilgan guruh yo'q."), findsOneWidget);
    });

    testWidgets('sog\'lom: so\'rov yiqilsa xato holati', (tester) async {
      api.on('/teacher/classes', status: 500, body: {'message': 'Yiqildi'});

      await pumpScreen(tester, const TestsScreen(showBack: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('P1-14 (TUZATILDI): xato holatida «Qayta urinish» bor va ISHLAYDI',
        (tester) async {
      // `IndexedStack` tabni tirik saqlagani uchun `initState` boshqa ishlamaydi —
      // qayta urinish affordansisiz oflayn ishga tushish abadiy qotib qolardi.
      api.on('/teacher/classes', status: 500, body: {'message': 'Yiqildi'});

      await pumpScreen(tester, const TestsScreen(showBack: true));
      await tester.pumpAndSettle();

      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      api.on('/teacher/classes', body: [
        {
          'classId': 'g1',
          'className': 'Ingliz A1',
          'subjects': [
            {'id': 'c1', 'name': 'Ingliz tili'}
          ],
        },
      ]);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();

      expect(find.text('Ingliz A1'), findsOneWidget);
      expect(find.text('Qayta urinish'), findsNothing);
    });

    testWidgets('P1-14 (TUZATILDI): bo\'sh holat ham pastga tortib yangilanadi', (tester) async {
      api.on('/teacher/classes', body: const <Object>[]);

      await pumpScreen(tester, const TestsScreen(showBack: true));
      await tester.pumpAndSettle();

      expect(find.text("Sizga biriktirilgan guruh yo'q."), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('SalaryScreen', () {
    testWidgets('sog\'lom: maosh ma\'lumoti bo\'lmasa bo\'sh holat', (tester) async {
      api.on('/teacher/salary', body: {
        'teacherId': 't1',
        'fullName': 'A. Voxidjonov',
        'salary': 0,
        'totalExpected': 0,
        'totalPaid': 0,
        'remaining': 0,
        'months': const <Object>[],
        'payments': const <Object>[],
      });

      await pumpScreen(tester, const SalaryScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining("Maosh ma'lumoti yo'q"), findsOneWidget);
    });

    testWidgets('sog\'lom: oylar bo\'lsa summalar formatlangan holda chiqadi', (tester) async {
      api.on('/teacher/salary', body: {
        'teacherId': 't1',
        'fullName': 'A. Voxidjonov',
        'salary': 5000000,
        'totalExpected': 5000000,
        'totalPaid': 3000000,
        'remaining': 2000000,
        'salaryMode': 'fixed',
        'months': [
          {
            'month': '2026-03',
            'expected': 5000000,
            'paid': 3000000,
            'remaining': 2000000,
            'status': 'partial',
          },
        ],
        'payments': const <Object>[],
      });

      await pumpScreen(tester, const SalaryScreen());
      await tester.pumpAndSettle();

      expect(find.text('5 000 000'), findsWidgets);
      expect(find.text('Qisman'), findsWidgets);
      // P1-13: yuklangan ro'yxat ham pastga tortib yangilanadi.
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('P1-13 (TUZATILDI): tarmoq xatosi «maosh yo\'q» deb ko\'rsatilmaydi',
        (tester) async {
      // Puli BOR o'qituvchiga "hisoblangan oylik mavjud emas" deb aytish mumkin emas.
      api.on('/teacher/salary', status: 500, body: {'message': 'Server yiqildi'});

      await pumpScreen(tester, const SalaryScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining("Maosh ma'lumoti yo'q"), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // «Qayta urinish» haqiqatan qayta yuklaydi.
      api.on('/teacher/salary', body: {
        'teacherId': 't1',
        'fullName': 'A. Voxidjonov',
        'salary': 5000000,
        'totalExpected': 5000000,
        'totalPaid': 3000000,
        'remaining': 2000000,
        'salaryMode': 'fixed',
        'months': [
          {
            'month': '2026-03',
            'expected': 5000000,
            'paid': 3000000,
            'remaining': 2000000,
            'status': 'partial',
          },
        ],
        'payments': const <Object>[],
      });
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();

      expect(find.text('5 000 000'), findsWidgets);
      expect(find.text('Qayta urinish'), findsNothing);
    });

    testWidgets('P1-13 (TUZATILDI): haqiqiy bo\'sh holat ham pastga tortib yangilanadi',
        (tester) async {
      api.on('/teacher/salary', body: {
        'teacherId': 't1',
        'fullName': 'A. Voxidjonov',
        'salary': 0,
        'totalExpected': 0,
        'totalPaid': 0,
        'remaining': 0,
        'months': const <Object>[],
        'payments': const <Object>[],
      });

      await pumpScreen(tester, const SalaryScreen());
      await tester.pumpAndSettle();

      expect(find.textContaining("Maosh ma'lumoti yo'q"), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  /* ================================================================ *
   *  «Aloqa» tabi va F.I.SH → surat oynasi
   * ================================================================ */

  group('GroupDetailScreen · aloqa va surat', () {
    void journalRoutes({List<Map<String, dynamic>> students = const []}) {
      api.on('/teacher/meta', body: _meta(const []));
      api.on('/teacher/journal/group',
          body: _journal(columns: const ['2026-03-05'], students: students));
      api.on('/teacher/grading/group', body: _emptyBoard);
    }

    testWidgets('«Aloqa» tabi bor va bosilganda navbat ro\'yxati ochiladi', (tester) async {
      journalRoutes(students: [_student('s1', 'Ali Valiyev')]);
      api.on('/teacher/contact-reasons', body: const <Object>[]);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      expect(find.text('Aloqa'), findsOneWidget);
      await tester.tap(find.text('Aloqa'));
      await tester.pumpAndSettle();

      expect(find.text('Hammasini tanlash'), findsOneWidget);
      expect(find.textContaining('Navbatga yuborish'), findsOneWidget);
      // Sabablar SHU tab ochilganda so'raladi (jurnal bilan birga emas).
      expect(api.countOf('/teacher/contact-reasons'), 1);
    });

    testWidgets('«Aloqa» tabida MUZLATILGAN o\'quvchi ko\'rinmaydi', (tester) async {
      journalRoutes(students: [
        _student('s1', 'Ali Valiyev'),
        _student('s2', 'Muzlagan Muzlatilov', status: 'frozen'),
      ]);
      api.on('/teacher/contact-reasons', body: const <Object>[]);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aloqa'));
      await tester.pumpAndSettle();

      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('Muzlagan Muzlatilov'), findsNothing);
    });

    testWidgets('jurnalda F.I.SH bosilsa SURAT oynasi ochiladi', (tester) async {
      journalRoutes(students: [_student('s1', 'Ali Valiyev')]);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Valiyev').first);
      await tester.pumpAndSettle();

      // Surati yo'q — oyna baribir ochiladi va sababini aytadi (jimgina
      // hech nima bo'lmasligi chalg'itardi).
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Rasm yuklanmagan'), findsOneWidget);
    });

    testWidgets('surati BOR o\'quvchida ism yonida ikonka turadi', (tester) async {
      journalRoutes(students: [
        _student('s1', 'Ali Valiyev', photoUrl: '/uploads/a.jpg'),
        _student('s2', 'Vali Aliyev'),
      ]);

      await pumpScreen(tester, _detail);
      await tester.pumpAndSettle();

      // Jurnal va Davomat tablari alohida chiziladi — bir vaqtda faqat biri
      // ko'rinadi, ya'ni ikonka ham bittadan bo'ladi.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });
}
