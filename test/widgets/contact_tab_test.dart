// Guruh jurnalidagi «ALOQA» tabi (`GroupContactTab`) uchun widget testlari.
//
// Bu tab o'quvchini "Bog'lanish kerak" navbatiga yuboradi. Qoidalari
// (`.claude/rules/contacts.md` §3.7) foydalanuvchiga ko'rinmaydigan, lekin
// buzilsa OG'IR oqibatli qoidalar — shuning uchun hammasi shu yerda qulflangan:
//   • sabab va izoh MAJBURIY (aks holda navbatga "sababsiz" talab tushardi);
//   • SANA umuman so'ralmaydi (rejalashtirish operatorning ishi);
//   • MUZLATILGAN o'quvchi ro'yxatda YO'Q, SINOVDAGI esa BOR;
//   • chetlab o'tilganlar (ochiq talabi bori) haqida xabar ko'rsatiladi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/models/models.dart';
import 'package:teacher/screens/group_contact_tab.dart';

import 'screen_harness.dart';

GroupJournalStudent _student(String id, String name, {String status = 'active'}) =>
    GroupJournalStudent.fromJson(<String, dynamic>{
      'studentId': id,
      'fullName': name,
      'status': status,
      'activatedAt': '2026-01-01',
      'balance': 0,
      'memberStart': '2026-01-01',
    });

/// Yuborilgan chaqiruvlarni yozib oladigan tab.
class _Recorder {
  final List<(List<String>, String, String)> calls = [];
  ContactBulkResult result = ContactBulkResult(
    created: 1,
    skipped: 0,
    skippedNames: const [],
    notFound: 0,
  );
  Object? error;

  Future<ContactBulkResult> send(List<String> ids, String reasonId, String note) async {
    calls.add((ids, reasonId, note));
    if (error != null) throw error!;
    return result;
  }
}

Widget _tab(
  List<GroupJournalStudent> students,
  _Recorder rec, {
  List<ContactReason>? reasons,
}) =>
    Scaffold(
      // Haqiqiy ilovada tab `SubScaffold` (Scaffold) ichida turadi.
      body: SingleChildScrollView(
        child: GroupContactTab(
          students: students,
          loadReasons: () async =>
              reasons ?? [ContactReason(id: 'r1', label: "To'lov kechikdi")],
          onSend: rec.send,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Recorder rec;

  setUp(() {
    installFakeApi();
    rec = _Recorder();
  });

  testWidgets('MUZLATILGAN ro\'yxatda yo\'q, SINOVDAGI bor', (tester) async {
    await pumpScreen(
      tester,
      _tab([
        _student('s1', 'Ali Valiyev'),
        _student('s2', 'Muzlagan Muzlatilov', status: 'frozen'),
        _student('s3', 'Sinov Sinovov', status: 'trial'),
      ], rec),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('Sinov Sinovov'), findsOneWidget);
    expect(find.text('Muzlagan Muzlatilov'), findsNothing);
    // Sinovdagi ekani belgisi bilan ko'rinadi.
    expect(find.text('Sinov'), findsOneWidget);
  });

  testWidgets('sabab va izoh bo\'lmasa YUBORILMAYDI (ikkala tugma ham o\'chiq)',
      (tester) async {
    await pumpScreen(tester, _tab([_student('s1', 'Ali Valiyev')], rec));
    await tester.pumpAndSettle();

    // Qatordagi tugma.
    await tester.tap(find.byIcon(Icons.phone_in_talk_rounded).last);
    await tester.pumpAndSettle();
    expect(rec.calls, isEmpty, reason: 'sabab/izohsiz talab navbatga tushmasligi kerak');
    expect(find.text("Sabab va izoh to'ldirilishi kerak"), findsOneWidget);
  });

  testWidgets('faqat izoh yozilsa ham yuborilmaydi (sabab MAJBURIY)', (tester) async {
    await pumpScreen(tester, _tab([_student('s1', 'Ali Valiyev')], rec));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'darsga kelmadi');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.phone_in_talk_rounded).last);
    await tester.pumpAndSettle();
    expect(rec.calls, isEmpty);
  });

  testWidgets('sabab + izoh to\'ldirilsa QATORDAGI tugma bitta o\'quvchini yuboradi',
      (tester) async {
    await pumpScreen(
      tester,
      _tab([_student('s1', 'Ali Valiyev'), _student('s2', 'Vali Aliyev')], rec),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("To'lov kechikdi").last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '  darsga kelmadi  ');
    await tester.pumpAndSettle();

    // Ro'yxatdagi BIRINCHI qator tugmasi (tepadagi ommaviy tugma — ikonka emas,
    // SButton ichida, shuning uchun `byIcon` faqat qatorlarni topadi... emas:
    // ommaviy tugmada ham ayni ikonka bor, u BIRINCHI keladi).
    final rowButtons = find.byIcon(Icons.phone_in_talk_rounded);
    await tester.tap(rowButtons.at(1));
    await tester.pumpAndSettle();

    expect(rec.calls, hasLength(1));
    final (ids, reasonId, note) = rec.calls.single;
    expect(ids, ['s1']);
    expect(reasonId, 'r1');
    // Izoh trim qilinadi.
    expect(note, 'darsga kelmadi');
  });

  testWidgets('«Hammasini tanlash» + ommaviy yuborish — hamma ko\'rinayotgan o\'quvchi',
      (tester) async {
    await pumpScreen(
      tester,
      _tab([
        _student('s1', 'Ali Valiyev'),
        _student('s2', 'Vali Aliyev'),
        _student('s3', 'Muzlagan', status: 'frozen'),
      ], rec),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("To'lov kechikdi").last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'izoh');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // "Hammasini tanlash"
    await tester.pumpAndSettle();
    expect(find.text('Navbatga yuborish (2)'), findsOneWidget);

    await tester.tap(find.text('Navbatga yuborish (2)'));
    await tester.pumpAndSettle();

    expect(rec.calls, hasLength(1));
    expect(rec.calls.single.$1, ['s1', 's2'],
        reason: 'muzlatilgan o\'quvchi tanlovga umuman tushmaydi');
    // Yuborilganlar tanlovdan chiqadi — ikki marta bosib yuborilmasin.
    expect(find.text('Navbatga yuborish (0)'), findsOneWidget);
  });

  testWidgets('chetlab o\'tilganlar (ochiq talabi bori) haqida xabar chiqadi',
      (tester) async {
    rec.result = ContactBulkResult(
      created: 1,
      skipped: 2,
      skippedNames: const ['Ali Valiyev'],
      notFound: 1,
    );
    await pumpScreen(tester, _tab([_student('s1', 'Ali Valiyev')], rec));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("To'lov kechikdi").last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'izoh');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.phone_in_talk_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.textContaining("1 ta o'quvchi navbatga yuborildi"), findsOneWidget);
    expect(find.textContaining('2 tasida allaqachon ochiq talab bor'), findsOneWidget);
    expect(find.textContaining('va boshqalar'), findsOneWidget);
    expect(find.textContaining("1 ta o'quvchi topilmadi"), findsOneWidget);
  });

  testWidgets('server xatosi ekranda ko\'rsatiladi (jimgina yutilmaydi)', (tester) async {
    rec.error = Exception('x');
    await pumpScreen(tester, _tab([_student('s1', 'Ali Valiyev')], rec));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("To'lov kechikdi").last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'izoh');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.phone_in_talk_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.text("Navbatga yuborib bo'lmadi"), findsOneWidget);
  });

  testWidgets('sabablar katalogi bo\'sh — tushuntirish matni chiqadi', (tester) async {
    await pumpScreen(tester, _tab([_student('s1', 'Ali')], rec, reasons: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining("Sabablar ro'yxati bo'sh"), findsOneWidget);
  });

  testWidgets('qidiruv — faqat mos o\'quvchi qoladi', (tester) async {
    await pumpScreen(
      tester,
      _tab([_student('s1', 'Ali Valiyev'), _student('s2', 'Vali Aliyev')], rec),
    );
    await tester.pumpAndSettle();

    // Ikkinchi TextField — qidiruv (birinchisi izoh).
    await tester.enterText(find.byType(TextField).at(1), 'vali a');
    await tester.pumpAndSettle();

    expect(find.text('Vali Aliyev'), findsOneWidget);
    expect(find.text('Ali Valiyev'), findsNothing);
  });

  testWidgets('guruhda o\'quvchi yo\'q — bo\'sh holat', (tester) async {
    await pumpScreen(tester, _tab(const [], rec));
    await tester.pumpAndSettle();

    expect(find.text("Guruhda o'quvchi yo'q"), findsOneWidget);
  });
}
