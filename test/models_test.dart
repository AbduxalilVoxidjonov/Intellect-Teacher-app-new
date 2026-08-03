// lib/models/models.dart uchun unit-testlar.
//
// Maqsad: har bir modelning `fromJson`/`toJson` xulqini qotirib qo'yish —
//   1) to'liq realistik JSON (happy path),
//   2) bo'sh JSON `{}` (default qiymatlar),
//   3) chegaraviy holatlar (null, noto'g'ri tip, bo'sh satr, ...).
//
// Private yordamchilar (_s/_sn/_i/_in/_d/_dn/_b/_bn/_list/_strList/_intList/_intMap)
// eksport qilinmagan — ular OMMAVIY `fromJson` fabrikalari orqali BILVOSITA tekshiriladi.
//
// Fayl oxirida "Tasdiqlangan defektlar" guruhi bor: har bir BUG-Mn uchun
//   (a) HOZIRGI xulqni qotiruvchi test (kelajakdagi tuzatish darrov ko'rinadi),
//   (b) `skip:` bilan belgilangan "to'g'ri xulq" testi (kutilgan shartnoma hujjati).

import 'package:flutter_test/flutter_test.dart';
import 'package:teacher/models/models.dart';

/// Skip sababi — barcha "to'g'ri xulq" testlari uchun bir xil shaklda.
String _skipReason(String bug) => "$bug — hozircha noto'g'ri ishlaydi";

void main() {
  /* ==================================================================
   * 0. Parsing yordamchilari — bilvosita (public fromJson orqali)
   * ================================================================== */

  group('_s (String, null → "")', () {
    test('null / kalit yo\'q / bo\'sh satr → bo\'sh satr', () {
      expect(Subject.fromJson({'id': null}).id, '');
      expect(Subject.fromJson({}).id, '');
      expect(Subject.fromJson({'id': ''}).id, '');
    });
    test('skalyarlar toString orqali satrga aylanadi', () {
      expect(Subject.fromJson({'id': 'abc'}).id, 'abc');
      expect(Subject.fromJson({'id': 42}).id, '42');
      expect(Subject.fromJson({'id': 4.5}).id, '4.5');
      expect(Subject.fromJson({'id': true}).id, 'true');
    });
    test('kollektsiyalar ham toString bo\'ladi (himoya yo\'q)', () {
      expect(ChatMessage.fromJson({'text': [1, 2]}).text, '[1, 2]');
      expect(ChatMessage.fromJson({'text': {'a': 1}}).text, '{a: 1}');
    });
  });

  group('_sn (String?, null → null)', () {
    test('null / kalit yo\'q → null', () {
      expect(AssignmentMaterial.fromJson({}).audioUrl, isNull);
      expect(AssignmentMaterial.fromJson({'audioUrl': null}).audioUrl, isNull);
    });
    test('qiymat bo\'lsa satrga aylanadi', () {
      expect(AssignmentMaterial.fromJson({'audioUrl': '/a.mp3'}).audioUrl, '/a.mp3');
      expect(AssignmentMaterial.fromJson({'audioUrl': 7}).audioUrl, '7');
    });
  });

  group('_i (int, null → 0)', () {
    test('null / kalit yo\'q → 0', () {
      expect(TeacherClass.fromJson({'grade': null}).grade, 0);
      expect(TeacherClass.fromJson({}).grade, 0);
    });
    test('num — double nolga qarab truncate qilinadi', () {
      expect(TeacherClass.fromJson({'grade': 9}).grade, 9);
      expect(TeacherClass.fromJson({'grade': -3}).grade, -3);
      expect(TeacherClass.fromJson({'grade': 3.9}).grade, 3);
      expect(TeacherClass.fromJson({'grade': -3.9}).grade, -3);
    });
    test('satrlar int.tryParse orqali (hex va probel ham)', () {
      expect(TeacherClass.fromJson({'grade': '11'}).grade, 11);
      expect(TeacherClass.fromJson({'grade': ' 7 '}).grade, 7);
      expect(TeacherClass.fromJson({'grade': '+5'}).grade, 5);
      expect(TeacherClass.fromJson({'grade': '0x10'}).grade, 16);
    });
    test('parse bo\'lmasa 0', () {
      expect(TeacherClass.fromJson({'grade': 'abc'}).grade, 0);
      expect(TeacherClass.fromJson({'grade': ''}).grade, 0);
      expect(TeacherClass.fromJson({'grade': true}).grade, 0);
    });
  });

  group('_in (int?, null → null)', () {
    test('null / kalit yo\'q → null, lekin 0 saqlanadi', () {
      expect(JournalEntry.fromJson({'grade': null}).grade, isNull);
      expect(JournalEntry.fromJson({}).grade, isNull);
      expect(JournalEntry.fromJson({'grade': 0}).grade, 0);
    });
    test('num va raqamli satr', () {
      expect(JournalEntry.fromJson({'grade': 5}).grade, 5);
      expect(JournalEntry.fromJson({'grade': 4.7}).grade, 4);
      expect(JournalEntry.fromJson({'grade': '3'}).grade, 3);
    });
    test('parse bo\'lmaydigan satr → null (0 emas!)', () {
      expect(JournalEntry.fromJson({'grade': 'x'}).grade, isNull);
      expect(JournalEntry.fromJson({'grade': ''}).grade, isNull);
    });
  });

  group('_d (double, null → 0.0)', () {
    test('null / kalit yo\'q → 0.0', () {
      expect(Subject.fromJson({'price': null}).price, 0.0);
      expect(Subject.fromJson({}).price, 0.0);
    });
    test('num → double', () {
      expect(Subject.fromJson({'price': 350000}).price, 350000.0);
      expect(Subject.fromJson({'price': 12.5}).price, 12.5);
      expect(Subject.fromJson({'price': -1.25}).price, -1.25);
    });
    test('satrlar double.tryParse orqali (eksponent, probel)', () {
      expect(Subject.fromJson({'price': '99.9'}).price, 99.9);
      expect(Subject.fromJson({'price': '1e3'}).price, 1000.0);
      expect(Subject.fromJson({'price': ' 1.5 '}).price, 1.5);
    });
    test('parse bo\'lmasa 0.0', () {
      expect(Subject.fromJson({'price': 'abc'}).price, 0.0);
      expect(Subject.fromJson({'price': ''}).price, 0.0);
      expect(Subject.fromJson({'price': true}).price, 0.0);
    });
  });

  group('_dn (double?, null → null)', () {
    test('null / kalit yo\'q → null, lekin 0 saqlanadi', () {
      expect(Subject.fromJson({'lessonPrice': null}).lessonPrice, isNull);
      expect(Subject.fromJson({}).lessonPrice, isNull);
      expect(Subject.fromJson({'lessonPrice': 0}).lessonPrice, 0.0);
    });
    test('qiymatlar va yaroqsiz satr', () {
      expect(Subject.fromJson({'lessonPrice': 30}).lessonPrice, 30.0);
      expect(Subject.fromJson({'lessonPrice': '45.5'}).lessonPrice, 45.5);
      expect(Subject.fromJson({'lessonPrice': 'yo\'q'}).lessonPrice, isNull);
    });
  });

  group('_b (bool, default false)', () {
    test('bool o\'zgarmaydi', () {
      expect(AbsenceReason.fromJson({'isLate': true}).isLate, isTrue);
      expect(AbsenceReason.fromJson({'isLate': false}).isLate, isFalse);
    });
    test('null / kalit yo\'q / boshqa tip → false', () {
      expect(AbsenceReason.fromJson({'isLate': null}).isLate, isFalse);
      expect(AbsenceReason.fromJson({}).isLate, isFalse);
      expect(AbsenceReason.fromJson({'isLate': []}).isLate, isFalse);
    });
    test('num: 0 → false, qolgani → true', () {
      expect(AbsenceReason.fromJson({'isLate': 1}).isLate, isTrue);
      expect(AbsenceReason.fromJson({'isLate': 0}).isLate, isFalse);
      expect(AbsenceReason.fromJson({'isLate': 0.0}).isLate, isFalse);
      expect(AbsenceReason.fromJson({'isLate': -1}).isLate, isTrue);
    });
    test('satr: faqat "true" (registrga sezgir emas)', () {
      expect(AbsenceReason.fromJson({'isLate': 'true'}).isLate, isTrue);
      expect(AbsenceReason.fromJson({'isLate': 'TrUe'}).isLate, isTrue);
      expect(AbsenceReason.fromJson({'isLate': 'false'}).isLate, isFalse);
    });
  });

  group('_bn (bool?, null → null)', () {
    test('null / kalit yo\'q → null', () {
      expect(TeacherProfile.fromJson({'isSupport': null}).isSupport, isNull);
      expect(TeacherProfile.fromJson({}).isSupport, isNull);
    });
    test('qiymat bo\'lsa _b qoidalari amal qiladi', () {
      expect(TeacherProfile.fromJson({'isSupport': true}).isSupport, isTrue);
      expect(TeacherProfile.fromJson({'isSupport': false}).isSupport, isFalse);
      expect(TeacherProfile.fromJson({'isSupport': 1}).isSupport, isTrue);
    });
  });

  group('_list (List<T>, null → [])', () {
    test('null / kalit yo\'q / [] → bo\'sh ro\'yxat', () {
      expect(TeacherClass.fromJson({'subjects': null}).subjects, isEmpty);
      expect(TeacherClass.fromJson({}).subjects, isEmpty);
      expect(TeacherClass.fromJson({'subjects': []}).subjects, isEmpty);
    });
    test('bitta element', () {
      final c = TeacherClass.fromJson({
        'subjects': [
          {'id': 's1', 'name': 'Ingliz tili', 'price': 400000}
        ]
      });
      expect(c.subjects, hasLength(1));
      expect(c.subjects.first.name, 'Ingliz tili');
      expect(c.subjects.first.price, 400000.0);
    });
    test('ko\'p element, tartib saqlanadi', () {
      final c = TeacherClass.fromJson({
        'subjects': [
          {'id': 'a'},
          {'id': 'b'},
          {'id': 'c'},
        ]
      });
      expect(c.subjects.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });
    test('Map<dynamic,dynamic> element ham qabul qilinadi', () {
      final raw = <dynamic, dynamic>{'id': 'x', 'name': 'Y'};
      final c = TeacherClass.fromJson({
        'subjects': [raw]
      });
      expect(c.subjects.single.name, 'Y');
    });
  });

  group('_strList (List<String>, null → [])', () {
    test('null / kalit yo\'q → []', () {
      expect(Assignment.fromJson({'classIds': null}).classIds, isEmpty);
      expect(Assignment.fromJson({}).classIds, isEmpty);
    });
    test('har bir element toString bo\'ladi', () {
      expect(Assignment.fromJson({'classIds': ['a', 'b']}).classIds, ['a', 'b']);
      expect(Assignment.fromJson({'classIds': [1, 2.5]}).classIds, ['1', '2.5']);
      expect(Assignment.fromJson({'classIds': [true]}).classIds, ['true']);
      expect(Assignment.fromJson({'classIds': ['']}).classIds, ['']);
    });
  });

  group('_intList (List<int>, null → [])', () {
    test('null / kalit yo\'q → []', () {
      expect(GroupJournalInfo.fromJson({'days': null}).days, isEmpty);
      expect(GroupJournalInfo.fromJson({}).days, isEmpty);
    });
    test('har bir element _i orqali o\'tadi', () {
      expect(GroupJournalInfo.fromJson({'days': [1, 3, 5]}).days, [1, 3, 5]);
      expect(GroupJournalInfo.fromJson({'days': ['2', '4']}).days, [2, 4]);
      expect(GroupJournalInfo.fromJson({'days': [1.9, 2.1]}).days, [1, 2]);
      expect(GroupJournalInfo.fromJson({'days': ['x']}).days, [0]);
    });
  });

  group('_intMap (Map<String,int>, null → {})', () {
    test('null / kalit yo\'q / {} → bo\'sh map', () {
      expect(EvaluationRow.fromJson({'grades': null}).grades, isEmpty);
      expect(EvaluationRow.fromJson({}).grades, isEmpty);
      expect(EvaluationRow.fromJson({'grades': {}}).grades, isEmpty);
    });
    test('qiymatlar _i orqali o\'tadi', () {
      expect(EvaluationRow.fromJson({'grades': {'t1': 5, 't2': 3}}).grades, {'t1': 5, 't2': 3});
      expect(EvaluationRow.fromJson({'grades': {'t1': '4'}}).grades, {'t1': 4});
      expect(EvaluationRow.fromJson({'grades': {'t1': 4.8}}).grades, {'t1': 4});
    });
    test('null/yaroqsiz qiymat → 0 (kalit qoladi)', () {
      expect(EvaluationRow.fromJson({'grades': {'t1': null}}).grades, {'t1': 0});
      expect(EvaluationRow.fromJson({'grades': {'t1': 'bad'}}).grades, {'t1': 0});
    });
  });

  /* ==================================================================
   * 1. Kurslar / guruhlar
   * ================================================================== */

  group('Subject', () {
    test('to\'liq JSON', () {
      final s = Subject.fromJson({
        'id': 'sub-1',
        'name': 'Matematika',
        'price': 450000,
        'lessonPrice': 37500.5,
      });
      expect(s.id, 'sub-1');
      expect(s.name, 'Matematika');
      expect(s.price, 450000.0);
      expect(s.lessonPrice, 37500.5);
    });
    test('bo\'sh JSON', () {
      final s = Subject.fromJson({});
      expect(s.id, '');
      expect(s.name, '');
      expect(s.price, 0.0);
      expect(s.lessonPrice, isNull);
    });
    test('lessonPrice = 0 → null emas',
        () => expect(Subject.fromJson({'lessonPrice': 0}).lessonPrice, 0.0));
  });

  group('TeacherClass', () {
    test('to\'liq JSON', () {
      final c = TeacherClass.fromJson({
        'classId': 'c-1',
        'className': 'Beginner A',
        'grade': 5,
        'subjects': [
          {'id': 's1', 'name': 'Ingliz tili', 'price': 400000, 'lessonPrice': 33000}
        ],
      });
      expect(c.classId, 'c-1');
      expect(c.className, 'Beginner A');
      expect(c.grade, 5);
      expect(c.subjects.single.lessonPrice, 33000.0);
    });
    test('bo\'sh JSON', () {
      final c = TeacherClass.fromJson({});
      expect(c.classId, '');
      expect(c.className, '');
      expect(c.grade, 0);
      expect(c.subjects, isEmpty);
    });
  });

  /* ==================================================================
   * 2. Baholash (evaluation)
   * ================================================================== */

  group('EvaluationType', () {
    test('to\'liq JSON', () {
      final t = EvaluationType.fromJson({'id': 'e1', 'name': 'Faollik', 'description': 'darsda'});
      expect([t.id, t.name, t.description], ['e1', 'Faollik', 'darsda']);
    });
    test('bo\'sh JSON', () {
      final t = EvaluationType.fromJson({});
      expect([t.id, t.name, t.description], ['', '', '']);
    });
  });

  group('AttendanceReasonCount', () {
    test('to\'liq JSON', () {
      final r = AttendanceReasonCount.fromJson({
        'reasonId': 'r1',
        'name': 'Kasal',
        'short': 'K',
        'isLate': false,
        'count': 3,
      });
      expect(r.reasonId, 'r1');
      expect(r.name, 'Kasal');
      expect(r.short, 'K');
      expect(r.isLate, isFalse);
      expect(r.count, 3);
    });
    test('bo\'sh JSON', () {
      final r = AttendanceReasonCount.fromJson({});
      expect(r.reasonId, '');
      expect(r.isLate, isFalse);
      expect(r.count, 0);
    });
    test('isLate raqam bilan',
        () => expect(AttendanceReasonCount.fromJson({'isLate': 1}).isLate, isTrue));
  });

  group('EvaluationRow', () {
    test('to\'liq JSON', () {
      final r = EvaluationRow.fromJson({
        'studentId': 'st-1',
        'fullName': 'Ali Valiyev',
        'className': 'Beginner A',
        'conducted': 20,
        'attended': 18,
        'reasons': [
          {'reasonId': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false, 'count': 2}
        ],
        'grades': {'e1': 5, 'e2': 4},
        'avgGrade': 4.5,
      });
      expect(r.studentId, 'st-1');
      expect(r.conducted, 20);
      expect(r.attended, 18);
      expect(r.reasons.single.count, 2);
      expect(r.grades, {'e1': 5, 'e2': 4});
      expect(r.avgGrade, 4.5);
    });
    test('bo\'sh JSON', () {
      final r = EvaluationRow.fromJson({});
      expect(r.fullName, '');
      expect(r.conducted, 0);
      expect(r.reasons, isEmpty);
      expect(r.grades, isEmpty);
      expect(r.avgGrade, 0.0);
    });
  });

  group('IdNameOption', () {
    test('to\'liq JSON', () {
      final o = IdNameOption.fromJson({'id': 'g1', 'name': 'Guruh 1'});
      expect([o.id, o.name], ['g1', 'Guruh 1']);
    });
    test('bo\'sh JSON', () => expect(IdNameOption.fromJson({}).id, ''));
  });

  group('EvaluationBoard', () {
    test('to\'liq JSON', () {
      final b = EvaluationBoard.fromJson({
        'months': ['2026-06', '2026-07'],
        'month': '2026-07',
        'week': 2,
        'types': [
          {'id': 'e1', 'name': 'Faollik', 'description': ''}
        ],
        'rows': [
          {'studentId': 'st-1', 'fullName': 'Ali'}
        ],
        'subjectId': 'sub-1',
        'subjects': [
          {'id': 'sub-1', 'name': 'Ingliz'}
        ],
        'groups': [
          {'id': 'g1', 'name': 'Guruh 1'}
        ],
        'groupId': 'g1',
      });
      expect(b.months, ['2026-06', '2026-07']);
      expect(b.month, '2026-07');
      expect(b.week, 2);
      expect(b.types.single.name, 'Faollik');
      expect(b.rows.single.fullName, 'Ali');
      expect(b.subjectId, 'sub-1');
      expect(b.subjects!.single.id, 'sub-1');
      expect(b.groups!.single.name, 'Guruh 1');
      expect(b.groupId, 'g1');
    });
    test('bo\'sh JSON — ixtiyoriy ro\'yxatlar null', () {
      final b = EvaluationBoard.fromJson({});
      expect(b.months, isEmpty);
      expect(b.month, '');
      expect(b.week, 0);
      expect(b.types, isEmpty);
      expect(b.rows, isEmpty);
      expect(b.subjectId, isNull);
      expect(b.subjects, isNull);
      expect(b.groups, isNull);
      expect(b.groupId, isNull);
    });
    test('subjects: [] → null emas, bo\'sh ro\'yxat',
        () => expect(EvaluationBoard.fromJson({'subjects': []}).subjects, isEmpty));
    test('groups: null → null',
        () => expect(EvaluationBoard.fromJson({'groups': null}).groups, isNull));
  });

  /* ==================================================================
   * 3. Topshiriqlar
   * ================================================================== */

  group('AssignmentMaterial', () {
    test('to\'liq JSON', () {
      final m = AssignmentMaterial.fromJson({
        'id': 'm-1',
        'name': 'unit1.pdf',
        'url': '/uploads/unit1.pdf',
        'size': 102400,
        'contentType': 'application/pdf',
        'audioUrl': '/uploads/a.mp3',
      });
      expect(m.id, 'm-1');
      expect(m.name, 'unit1.pdf');
      expect(m.url, '/uploads/unit1.pdf');
      expect(m.size, 102400);
      expect(m.contentType, 'application/pdf');
      expect(m.audioUrl, '/uploads/a.mp3');
    });
    test('bo\'sh JSON', () {
      final m = AssignmentMaterial.fromJson({});
      expect(m.id, '');
      expect(m.size, 0);
      expect(m.audioUrl, isNull);
    });
    test('size satr sifatida', () => expect(AssignmentMaterial.fromJson({'size': '2048'}).size, 2048));
  });

  group('MaterialInput', () {
    test('fromJson to\'liq', () {
      final m = MaterialInput.fromJson({
        'name': 'a.pdf',
        'url': '/u/a.pdf',
        'size': 10,
        'contentType': 'application/pdf',
        'audioUrl': null,
      });
      expect(m.name, 'a.pdf');
      expect(m.size, 10);
      expect(m.audioUrl, isNull);
    });
    test('fromJson bo\'sh', () {
      final m = MaterialInput.fromJson({});
      expect(m.name, '');
      expect(m.url, '');
      expect(m.size, 0);
      expect(m.contentType, '');
      expect(m.audioUrl, isNull);
    });
    test('toJson barcha maydonlarni beradi', () {
      final j = MaterialInput(
        name: 'a.pdf',
        url: '/u/a.pdf',
        size: 10,
        contentType: 'application/pdf',
        audioUrl: '/u/a.mp3',
      ).toJson();
      expect(j, {
        'name': 'a.pdf',
        'url': '/u/a.pdf',
        'size': 10,
        'contentType': 'application/pdf',
        'audioUrl': '/u/a.mp3',
      });
    });
    test('fromJson → toJson → fromJson aylanma', () {
      const src = {
        'name': 'b.mp3',
        'url': '/u/b.mp3',
        'size': 999,
        'contentType': 'audio/mpeg',
        'audioUrl': '/u/b.mp3',
      };
      final round = MaterialInput.fromJson(MaterialInput.fromJson(src).toJson());
      expect(round.toJson(), src);
    });
  });

  group('TestQuestion', () {
    test('to\'liq JSON', () {
      final q = TestQuestion.fromJson({
        'id': 'q-1',
        'text': '2+2=?',
        'options': ['3', '4', '5'],
        'correctIndex': 1,
        'order': 0,
      });
      expect(q.id, 'q-1');
      expect(q.text, '2+2=?');
      expect(q.options, ['3', '4', '5']);
      expect(q.correctIndex, 1);
      expect(q.order, 0);
    });
    test('bo\'sh JSON', () {
      final q = TestQuestion.fromJson({});
      expect(q.options, isEmpty);
      expect(q.correctIndex, 0);
      expect(q.order, 0);
    });
    test('correctIndex chegaradan tashqari — model tekshirmaydi',
        () => expect(TestQuestion.fromJson({'options': ['a'], 'correctIndex': 9}).correctIndex, 9));
  });

  group('QuestionInput', () {
    test('fromJson to\'liq', () {
      final q = QuestionInput.fromJson({
        'text': 'Poytaxt?',
        'options': ['Toshkent', 'Samarqand'],
        'correctIndex': 0,
      });
      expect(q.text, 'Poytaxt?');
      expect(q.options, hasLength(2));
      expect(q.correctIndex, 0);
    });
    test('fromJson bo\'sh', () {
      final q = QuestionInput.fromJson({});
      expect(q.text, '');
      expect(q.options, isEmpty);
      expect(q.correctIndex, 0);
    });
    test('toJson', () {
      final j = QuestionInput(text: 'T', options: ['a', 'b'], correctIndex: 1).toJson();
      expect(j, {'text': 'T', 'options': ['a', 'b'], 'correctIndex': 1});
    });
    test('toJson options — o\'sha ro\'yxat obyekti', () {
      final q = QuestionInput(text: 'T', options: ['a'], correctIndex: 0);
      expect(q.toJson()['options'], same(q.options));
    });
    test('aylanma fromJson→toJson', () {
      const src = {'text': 'X', 'options': ['1', '2'], 'correctIndex': 1};
      expect(QuestionInput.fromJson(src).toJson(), src);
    });
  });

  group('SaveAssignmentInput.toJson', () {
    SaveAssignmentInput build({
      String? description,
      String? startDate,
      String? dueDate,
      String? referenceText,
      List<MaterialInput>? materials,
      List<QuestionInput>? questions,
    }) =>
        SaveAssignmentInput(
          subjectId: 'sub-1',
          title: 'Uy ishi',
          description: description,
          format: 'written',
          classIds: ['c1', 'c2'],
          startDate: startDate,
          dueDate: dueDate,
          lateAccept: true,
          latePenaltyPct: 10,
          maxScore: 100,
          autoGrade: false,
          materials: materials ?? const [],
          questions: questions ?? const [],
          referenceText: referenceText,
        );

    test('to\'liq — barcha maydonlar', () {
      final j = build(
        description: 'tavsif',
        startDate: '2026-08-01',
        dueDate: '2026-08-10',
        referenceText: 'Read this',
        materials: [
          MaterialInput(name: 'a.pdf', url: '/u/a', size: 1, contentType: 'application/pdf')
        ],
        questions: [QuestionInput(text: 'q', options: ['a', 'b'], correctIndex: 1)],
      ).toJson();
      expect(j['subjectId'], 'sub-1');
      expect(j['title'], 'Uy ishi');
      expect(j['description'], 'tavsif');
      expect(j['format'], 'written');
      expect(j['classIds'], ['c1', 'c2']);
      expect(j['startDate'], '2026-08-01');
      expect(j['dueDate'], '2026-08-10');
      expect(j['lateAccept'], isTrue);
      expect(j['latePenaltyPct'], 10.0);
      expect(j['maxScore'], 100.0);
      expect(j['autoGrade'], isFalse);
      expect(j['referenceText'], 'Read this');
    });
    test('materials/questions ichki toJson chaqiriladi', () {
      final j = build(
        materials: [MaterialInput(name: 'a', url: 'u', size: 2, contentType: 'ct')],
        questions: [QuestionInput(text: 'q', options: ['x'], correctIndex: 0)],
      ).toJson();
      expect(j['materials'], isA<List<Map<String, dynamic>>>());
      expect((j['materials'] as List).single, containsPair('name', 'a'));
      expect((j['questions'] as List).single, containsPair('correctIndex', 0));
    });
    test('bo\'sh materials/questions → bo\'sh ro\'yxat', () {
      final j = build().toJson();
      expect(j['materials'], isEmpty);
      expect(j['questions'], isEmpty);
    });
    test('kalitlar to\'plami barqaror', () {
      expect(
        build().toJson().keys.toSet(),
        {
          'subjectId', 'title', 'description', 'format', 'classIds', 'startDate',
          'dueDate', 'lateAccept', 'latePenaltyPct', 'maxScore', 'autoGrade',
          'materials', 'questions', 'referenceText',
        },
      );
    });
  });

  group('Assignment', () {
    test('to\'liq JSON', () {
      final a = Assignment.fromJson({
        'id': 'a-1',
        'createdByUserId': 'u-1',
        'subjectId': 'sub-1',
        'subjectName': 'Ingliz tili',
        'title': 'Unit 3',
        'description': 'Grammar',
        'format': 'test',
        'classIds': ['c1'],
        'classNames': ['Beginner A'],
        'startDate': '2026-08-01T09:00',
        'dueDate': '2026-08-05T23:59',
        'lateAccept': true,
        'latePenaltyPct': 25,
        'maxScore': 50,
        'autoGrade': true,
        'createdAt': '2026-07-30T12:00:00Z',
        'materials': [
          {'id': 'm1', 'name': 'a.pdf', 'url': '/u/a', 'size': 3, 'contentType': 'application/pdf'}
        ],
        'questions': [
          {'id': 'q1', 'text': 'T', 'options': ['a', 'b'], 'correctIndex': 0, 'order': 1}
        ],
        'referenceText': 'read me',
      });
      expect(a.id, 'a-1');
      expect(a.subjectName, 'Ingliz tili');
      expect(a.format, 'test');
      expect(a.classIds, ['c1']);
      expect(a.classNames, ['Beginner A']);
      expect(a.startDate, '2026-08-01T09:00');
      expect(a.lateAccept, isTrue);
      expect(a.latePenaltyPct, 25.0);
      expect(a.maxScore, 50.0);
      expect(a.autoGrade, isTrue);
      expect(a.materials.single.id, 'm1');
      expect(a.questions.single.options, ['a', 'b']);
      expect(a.referenceText, 'read me');
    });
    test('bo\'sh JSON', () {
      final a = Assignment.fromJson({});
      expect(a.id, '');
      expect(a.format, '');
      expect(a.classIds, isEmpty);
      expect(a.classNames, isEmpty);
      expect(a.startDate, isNull);
      expect(a.dueDate, isNull);
      expect(a.lateAccept, isFalse);
      expect(a.latePenaltyPct, 0.0);
      expect(a.autoGrade, isFalse);
      expect(a.materials, isEmpty);
      expect(a.questions, isEmpty);
      expect(a.referenceText, isNull);
    });
    test('startDate null bo\'lsa null qoladi',
        () => expect(Assignment.fromJson({'startDate': null}).startDate, isNull));
  });

  group('AssignmentType', () {
    test('to\'liq JSON', () {
      final t = AssignmentType.fromJson({'id': 't1', 'name': 'Uy ishi'});
      expect([t.id, t.name], ['t1', 'Uy ishi']);
    });
    test('bo\'sh JSON', () => expect(AssignmentType.fromJson({}).name, ''));
  });

  group('SubmissionRow', () {
    test('to\'liq JSON', () {
      final r = SubmissionRow.fromJson({
        'studentId': 'st-1',
        'studentName': 'Ali',
        'className': 'A',
        'completed': true,
        'submittedAt': '2026-08-02T10:00',
        'score': 47.5,
        'answerText': 'javob',
        'fileUrl': '/u/f.pdf',
      });
      expect(r.studentId, 'st-1');
      expect(r.completed, isTrue);
      expect(r.submittedAt, '2026-08-02T10:00');
      expect(r.score, 47.5);
      expect(r.answerText, 'javob');
      expect(r.fileUrl, '/u/f.pdf');
    });
    test('bo\'sh JSON', () {
      final r = SubmissionRow.fromJson({});
      expect(r.completed, isFalse);
      expect(r.submittedAt, isNull);
      expect(r.score, isNull);
      expect(r.answerText, isNull);
      expect(r.fileUrl, isNull);
    });
    test('score 0 → null emas', () => expect(SubmissionRow.fromJson({'score': 0}).score, 0.0));
  });

  group('AssignmentResult', () {
    test('to\'liq JSON', () {
      final r = AssignmentResult.fromJson({
        'assignmentId': 'a-1',
        'title': 'Unit 3',
        'format': 'file',
        'maxScore': 100,
        'total': 12,
        'completedCount': 7,
        'rows': [
          {'studentId': 'st-1', 'completed': true},
          {'studentId': 'st-2', 'completed': false},
        ],
      });
      expect(r.assignmentId, 'a-1');
      expect(r.format, 'file');
      expect(r.maxScore, 100.0);
      expect(r.total, 12);
      expect(r.completedCount, 7);
      expect(r.rows, hasLength(2));
      expect(r.rows.last.completed, isFalse);
    });
    test('bo\'sh JSON', () {
      final r = AssignmentResult.fromJson({});
      expect(r.total, 0);
      expect(r.completedCount, 0);
      expect(r.rows, isEmpty);
    });
  });

  /* ==================================================================
   * 4. Chat / portal meta
   * ================================================================== */

  group('ChatMessage', () {
    test('to\'liq JSON', () {
      final m = ChatMessage.fromJson({
        'id': 'msg-1',
        'className': 'Beginner A',
        'senderUserId': 'u-1',
        'senderName': 'Ustoz',
        'senderRole': 'teacher',
        'text': 'Salom',
        'createdAt': '2026-08-01T08:00:00Z',
      });
      expect(m.id, 'msg-1');
      expect(m.senderRole, 'teacher');
      expect(m.text, 'Salom');
      expect(m.createdAt, '2026-08-01T08:00:00Z');
    });
    test('bo\'sh JSON', () {
      final m = ChatMessage.fromJson({});
      expect([m.id, m.className, m.senderUserId, m.senderName, m.senderRole, m.text, m.createdAt],
          ['', '', '', '', '', '', '']);
    });
    test('text null → bo\'sh satr', () => expect(ChatMessage.fromJson({'text': null}).text, ''));
  });

  group('QuarterPeriod', () {
    test('to\'liq JSON', () {
      final q = QuarterPeriod.fromJson({
        'quarter': 1,
        'startDate': '2026-09-01',
        'endDate': '2026-10-30',
        'gradesOpen': true,
      });
      expect(q.quarter, 1);
      expect(q.startDate, '2026-09-01');
      expect(q.endDate, '2026-10-30');
      expect(q.gradesOpen, isTrue);
    });
    test('bo\'sh JSON', () {
      final q = QuarterPeriod.fromJson({});
      expect(q.quarter, 0);
      expect(q.gradesOpen, isFalse);
    });
  });

  group('AbsenceReason', () {
    test('to\'liq JSON', () {
      final r = AbsenceReason.fromJson({'id': 'r1', 'name': 'Kechikdi', 'short': 'Kch', 'isLate': true});
      expect(r.id, 'r1');
      expect(r.name, 'Kechikdi');
      expect(r.short, 'Kch');
      expect(r.isLate, isTrue);
    });
    test('bo\'sh JSON', () {
      final r = AbsenceReason.fromJson({});
      expect(r.id, '');
      expect(r.isLate, isFalse);
    });
  });

  group('PortalMeta', () {
    test('to\'liq JSON', () {
      final m = PortalMeta.fromJson({
        'quarters': [
          {'quarter': 1, 'startDate': '2026-09-01', 'endDate': '2026-10-30', 'gradesOpen': true}
        ],
        'absenceReasons': [
          {'id': 'r1', 'name': 'Kasal', 'short': 'K', 'isLate': false}
        ],
        'currentQuarter': 1,
        'currentWeek': 4,
      });
      expect(m.quarters.single.quarter, 1);
      expect(m.absenceReasons.single.short, 'K');
      expect(m.currentQuarter, 1);
      expect(m.currentWeek, 4);
    });
    test('bo\'sh JSON', () {
      final m = PortalMeta.fromJson({});
      expect(m.quarters, isEmpty);
      expect(m.absenceReasons, isEmpty);
      expect(m.currentQuarter, 0);
      expect(m.currentWeek, 0);
    });
  });

  /* ==================================================================
   * 5. Maosh
   * ================================================================== */

  group('LedgerPayment', () {
    test('to\'liq JSON', () {
      final p = LedgerPayment.fromJson({
        'date': '2026-07-05',
        'amount': 2500000,
        'note': 'avans',
        'comment': 'naqd',
        'month': '2026-07',
        'method': 'cash',
      });
      expect(p.date, '2026-07-05');
      expect(p.amount, 2500000.0);
      expect(p.note, 'avans');
      expect(p.comment, 'naqd');
      expect(p.month, '2026-07');
      expect(p.method, 'cash');
    });
    test('bo\'sh JSON', () {
      final p = LedgerPayment.fromJson({});
      expect(p.date, '');
      expect(p.amount, 0.0);
      expect(p.note, isNull);
      expect(p.comment, isNull);
      expect(p.month, isNull);
      expect(p.method, isNull);
    });
  });

  group('SalaryLessonStat', () {
    test('to\'liq JSON', () {
      final s = SalaryLessonStat.fromJson({
        'groupId': 'g1',
        'groupName': 'Guruh 1',
        'planned': 12,
        'conducted': 10,
        'missed': 2,
        'deduction': 150000,
        'missedDates': ['2026-07-03', '2026-07-10'],
      });
      expect(s.groupId, 'g1');
      expect(s.planned, 12);
      expect(s.conducted, 10);
      expect(s.missed, 2);
      expect(s.deduction, 150000.0);
      expect(s.missedDates, hasLength(2));
    });
    test('bo\'sh JSON', () {
      final s = SalaryLessonStat.fromJson({});
      expect(s.planned, 0);
      expect(s.deduction, 0.0);
      expect(s.missedDates, isEmpty);
    });
  });

  group('MonthSalary', () {
    test('to\'liq JSON', () {
      final m = MonthSalary.fromJson({
        'month': '2026-07',
        'expected': 5000000,
        'paid': 3000000,
        'remaining': 2000000,
        'status': 'partial',
        'baseExpected': 5200000,
        'deduction': 200000,
        'plannedLessons': 12,
        'conductedLessons': 11,
        'missedLessons': 1,
        'lessons': [
          {'groupId': 'g1', 'planned': 12, 'conducted': 11}
        ],
      });
      expect(m.month, '2026-07');
      expect(m.expected, 5000000.0);
      expect(m.status, 'partial');
      expect(m.baseExpected, 5200000.0);
      expect(m.deduction, 200000.0);
      expect(m.plannedLessons, 12);
      expect(m.conductedLessons, 11);
      expect(m.missedLessons, 1);
      expect(m.lessons!.single.groupId, 'g1');
    });
    test('collected — SHU OY UCHUN yig\'ilgan (foizli maosh bazasi)', () {
      // To'lov QAYSI OY UCHUN qilingan bo'lsa shu oyga kiradi (to'lov sanasi emas):
      // 3-avgustda iyul uchun to'langan pul iyul qatorida ko'rinadi.
      final m = MonthSalary.fromJson({'month': '2026-07', 'collected': 6000000});
      expect(m.collected, 6000000.0);
      // Berilmasa 0 — qat'iy maoshda yig'ilgan baza ma'noga ega emas.
      expect(MonthSalary.fromJson({'month': '2026-07'}).collected, 0.0);
    });
    test('bo\'sh JSON — ixtiyoriylar null', () {
      final m = MonthSalary.fromJson({});
      expect(m.month, '');
      expect(m.expected, 0.0);
      expect(m.status, '');
      expect(m.baseExpected, isNull);
      expect(m.deduction, isNull);
      expect(m.plannedLessons, isNull);
      expect(m.lessons, isNull);
    });
    test('lessons: [] → bo\'sh ro\'yxat (null emas)',
        () => expect(MonthSalary.fromJson({'lessons': []}).lessons, isEmpty));
  });

  group('GroupSalaryLine', () {
    test('to\'liq JSON', () {
      final g = GroupSalaryLine.fromJson({
        'groupId': 'g1',
        'groupName': 'Guruh 1',
        'courseName': 'Ingliz tili',
        'monthlyFee': 400000,
        'mode': 'percent',
        'percent': 40,
        'fixed': 0,
        'periodCollected': 4000000,
        'periodExpected': 5000000,
      });
      expect(g.groupName, 'Guruh 1');
      expect(g.mode, 'percent');
      expect(g.percent, 40.0);
      expect(g.fixed, 0.0);
      expect(g.periodCollected, 4000000.0);
      expect(g.periodExpected, 5000000.0);
    });
    test('bo\'sh JSON', () {
      final g = GroupSalaryLine.fromJson({});
      expect(g.mode, '');
      expect(g.monthlyFee, 0.0);
      expect(g.percent, 0.0);
    });
  });

  group('SalaryLedger', () {
    test('to\'liq JSON', () {
      final l = SalaryLedger.fromJson({
        'teacherId': 't-1',
        'fullName': 'Ustoz Aka',
        'salary': 6000000,
        'totalExpected': 12000000,
        'totalPaid': 9000000,
        'remaining': 3000000,
        'months': [
          {'month': '2026-06', 'expected': 6000000, 'status': 'paid'}
        ],
        'payments': [
          {'date': '2026-06-30', 'amount': 6000000}
        ],
        'salaryMode': 'percent',
        'salaryPercent': 40,
        'groups': [
          {'groupId': 'g1', 'mode': 'percent'}
        ],
        'totalDeduction': 350000,
        'journalLinked': true,
      });
      expect(l.teacherId, 't-1');
      expect(l.salary, 6000000.0);
      expect(l.months.single.status, 'paid');
      expect(l.payments.single.amount, 6000000.0);
      expect(l.salaryMode, 'percent');
      expect(l.salaryPercent, 40.0);
      expect(l.groups!.single.groupId, 'g1');
      expect(l.totalDeduction, 350000.0);
      expect(l.journalLinked, isTrue);
    });
    test('bo\'sh JSON', () {
      final l = SalaryLedger.fromJson({});
      expect(l.months, isEmpty);
      expect(l.payments, isEmpty);
      expect(l.salaryMode, isNull);
      expect(l.salaryPercent, isNull);
      expect(l.groups, isNull);
      expect(l.totalDeduction, isNull);
      expect(l.journalLinked, isNull);
    });
    test('journalLinked: 0 → false',
        () => expect(SalaryLedger.fromJson({'journalLinked': 0}).journalLinked, isFalse));
  });

  /* ==================================================================
   * 6. Guruh jurnali
   * ================================================================== */

  group('JournalColumn', () {
    test('to\'liq JSON', () {
      final c = JournalColumn.fromJson({'date': '2026-08-03', 'period': 1});
      expect(c.date, '2026-08-03');
      expect(c.period, 1);
    });
    test('bo\'sh JSON', () {
      final c = JournalColumn.fromJson({});
      expect(c.date, '');
      expect(c.period, 0);
    });
  });

  group('JournalEntry', () {
    test('to\'liq JSON', () {
      final e = JournalEntry.fromJson({
        'studentId': 'st-1',
        'date': '2026-08-03',
        'period': 1,
        'grade': 5,
        'reasonId': 'r1',
        'homework': 1,
        'behavior': 2,
        'mastery': 3,
        'present': true,
      });
      expect(e.studentId, 'st-1');
      expect(e.period, 1);
      expect(e.grade, 5);
      expect(e.reasonId, 'r1');
      expect(e.homework, 1);
      expect(e.behavior, 2);
      expect(e.mastery, 3);
      expect(e.present, isTrue);
    });
    test('bo\'sh JSON — ixtiyoriylar null, present false', () {
      final e = JournalEntry.fromJson({});
      expect(e.grade, isNull);
      expect(e.reasonId, isNull);
      expect(e.homework, isNull);
      expect(e.behavior, isNull);
      expect(e.mastery, isNull);
      expect(e.present, isFalse);
    });
    test('mastery = 0 (NonReactive) null emas',
        () => expect(JournalEntry.fromJson({'mastery': 0}).mastery, 0));
    test('homework = 0 (belgilanmagan) null emas',
        () => expect(JournalEntry.fromJson({'homework': 0}).homework, 0));
  });

  group('JournalTopic', () {
    test('to\'liq JSON', () {
      final t = JournalTopic.fromJson({
        'date': '2026-08-03',
        'period': 2,
        'topic': 'Present Perfect',
        'homework': 'WB p.20',
        'conducted': true,
      });
      expect(t.topic, 'Present Perfect');
      expect(t.homework, 'WB p.20');
      expect(t.conducted, isTrue);
    });
    test('bo\'sh JSON', () {
      final t = JournalTopic.fromJson({});
      expect(t.topic, '');
      expect(t.homework, isNull);
      expect(t.conducted, isFalse);
    });
  });

  group('GroupJournalInfo', () {
    test('to\'liq JSON', () {
      final g = GroupJournalInfo.fromJson({
        'id': 'g1',
        'name': 'Beginner A',
        'courseId': 'c1',
        'courseName': 'Ingliz tili',
        'teacherName': 'Ustoz',
        'days': [1, 3, 5],
        'startTime': '09:00',
        'endTime': '10:30',
        'room': '204',
        'startDate': '2026-06-01',
        'monthlyFee': 400000,
      });
      expect(g.id, 'g1');
      expect(g.days, [1, 3, 5]);
      expect(g.startTime, '09:00');
      expect(g.endTime, '10:30');
      expect(g.room, '204');
      expect(g.monthlyFee, 400000.0);
    });
    test('bo\'sh JSON', () {
      final g = GroupJournalInfo.fromJson({});
      expect(g.days, isEmpty);
      expect(g.monthlyFee, 0.0);
      expect(g.room, '');
    });
  });

  group('GroupJournalStudent', () {
    test('to\'liq JSON', () {
      final s = GroupJournalStudent.fromJson({
        'studentId': 'st-1',
        'fullName': 'Ali Valiyev',
        'status': 'active',
        'activatedAt': '2026-06-01',
        'balance': -200000,
        'memberStart': '2026-06-01',
        'presentDefaultFrom': '2026-06-05',
        'frozenAt': '',
        'debtMonths': 2,
      });
      expect(s.studentId, 'st-1');
      expect(s.status, 'active');
      expect(s.balance, -200000.0);
      expect(s.memberStart, '2026-06-01');
      expect(s.presentDefaultFrom, '2026-06-05');
      expect(s.frozenAt, '');
      expect(s.debtMonths, 2);
    });
    test('bo\'sh JSON — string default lar bo\'sh satr', () {
      final s = GroupJournalStudent.fromJson({});
      expect(s.balance, 0.0);
      expect(s.presentDefaultFrom, '');
      expect(s.frozenAt, '');
      expect(s.debtMonths, 0);
    });
    test('frozenAt null → bo\'sh satr',
        () => expect(GroupJournalStudent.fromJson({'frozenAt': null}).frozenAt, ''));
  });

  group('LessonReschedule', () {
    test('to\'liq JSON', () {
      final r = LessonReschedule.fromJson({
        'id': 'rs-1',
        'fromDate': '2026-08-03',
        'toDate': '2026-08-04',
        'time': '09:00',
      });
      expect(r.id, 'rs-1');
      expect(r.fromDate, '2026-08-03');
      expect(r.toDate, '2026-08-04');
      expect(r.time, '09:00');
    });
    test('bo\'sh JSON', () {
      final r = LessonReschedule.fromJson({});
      expect(r.id, '');
      expect(r.time, isNull);
    });
  });

  group('GroupJournal', () {
    test('to\'liq JSON', () {
      final j = GroupJournal.fromJson({
        'group': {'id': 'g1', 'name': 'Beginner A', 'days': [1, 3], 'monthlyFee': 400000},
        'months': ['2026-07', '2026-08'],
        'month': '2026-08',
        'columns': [
          {'date': '2026-08-03', 'period': 1}
        ],
        'students': [
          {'studentId': 'st-1', 'fullName': 'Ali'}
        ],
        'entries': [
          {'studentId': 'st-1', 'date': '2026-08-03', 'period': 1, 'present': true}
        ],
        'conductedDates': ['2026-08-03'],
        'reschedules': [
          {'id': 'rs-1', 'fromDate': '2026-08-05', 'toDate': '2026-08-06'}
        ],
      });
      expect(j.group.name, 'Beginner A');
      expect(j.group.days, [1, 3]);
      expect(j.months, ['2026-07', '2026-08']);
      expect(j.month, '2026-08');
      expect(j.columns.single.period, 1);
      expect(j.students.single.fullName, 'Ali');
      expect(j.entries.single.present, isTrue);
      expect(j.conductedDates, ['2026-08-03']);
      expect(j.reschedules.single.toDate, '2026-08-06');
    });
    test('group bor, qolganlari yo\'q → hammasi bo\'sh', () {
      final j = GroupJournal.fromJson({'group': <String, dynamic>{}});
      expect(j.group.id, '');
      expect(j.months, isEmpty);
      expect(j.month, '');
      expect(j.columns, isEmpty);
      expect(j.students, isEmpty);
      expect(j.entries, isEmpty);
      expect(j.conductedDates, isEmpty);
      expect(j.reschedules, isEmpty);
    });
  });

  /* ==================================================================
   * 7. Baholash mezonlari (grading board)
   * ================================================================== */

  group('GradingBoardCriterion', () {
    test('to\'liq JSON', () {
      final c = GradingBoardCriterion.fromJson({'id': 'cr1', 'name': 'Uy ishi', 'order': 2});
      expect([c.id, c.name], ['cr1', 'Uy ishi']);
      expect(c.order, 2);
    });
    test('bo\'sh JSON', () => expect(GradingBoardCriterion.fromJson({}).order, 0));
  });

  group('GradingBoardStudent', () {
    test('to\'liq JSON', () {
      final s = GradingBoardStudent.fromJson({
        'studentId': 'st-1',
        'fullName': 'Ali',
        'doneKeys': ['cr1|2026-08-03', 'cr2|2026-08-03'],
      });
      expect(s.fullName, 'Ali');
      expect(s.doneKeys, hasLength(2));
      expect(s.doneKeys.first, 'cr1|2026-08-03');
    });
    test('bo\'sh JSON', () => expect(GradingBoardStudent.fromJson({}).doneKeys, isEmpty));
  });

  group('GradingBoard', () {
    test('to\'liq JSON', () {
      final b = GradingBoard.fromJson({
        'groupId': 'g1',
        'groupName': 'Beginner A',
        'months': ['2026-08'],
        'month': '2026-08',
        'dates': ['2026-08-03', '2026-08-05'],
        'criteria': [
          {'id': 'cr1', 'name': 'Uy ishi', 'order': 1}
        ],
        'students': [
          {'studentId': 'st-1', 'fullName': 'Ali', 'doneKeys': ['cr1|2026-08-03']}
        ],
      });
      expect(b.groupId, 'g1');
      expect(b.dates, hasLength(2));
      expect(b.criteria.single.name, 'Uy ishi');
      expect(b.students.single.doneKeys, ['cr1|2026-08-03']);
    });
    test('bo\'sh JSON', () {
      final b = GradingBoard.fromJson({});
      expect(b.months, isEmpty);
      expect(b.dates, isEmpty);
      expect(b.criteria, isEmpty);
      expect(b.students, isEmpty);
    });
  });

  group('SetGrade.toJson', () {
    test('barcha maydonlar', () {
      final j = SetGrade(
        groupId: 'g1',
        studentId: 'st-1',
        criterionId: 'cr1',
        date: '2026-08-03',
        done: true,
      ).toJson();
      expect(j, {
        'groupId': 'g1',
        'studentId': 'st-1',
        'criterionId': 'cr1',
        'date': '2026-08-03',
        'done': true,
      });
    });
    test('done=false ham yoziladi', () {
      final j = SetGrade(groupId: '', studentId: '', criterionId: '', date: '', done: false)
          .toJson();
      expect(j['done'], isFalse);
      expect(j.keys, hasLength(5));
    });
  });

  group('BulkGrade.toJson', () {
    test('barcha maydonlar', () {
      final j = BulkGrade(groupId: 'g1', criterionId: 'cr1', date: '2026-08-03', done: true)
          .toJson();
      expect(j, {'groupId': 'g1', 'criterionId': 'cr1', 'date': '2026-08-03', 'done': true});
    });
    test('studentId yo\'q (SetGrade dan farqi)', () {
      final j = BulkGrade(groupId: 'g1', criterionId: 'c', date: 'd', done: false).toJson();
      expect(j.containsKey('studentId'), isFalse);
      expect(j.keys, hasLength(4));
    });
  });

  /* ==================================================================
   * 8. O'quv dasturi (curriculum)
   * ================================================================== */

  group('GroupCurriculumItem', () {
    test('to\'liq JSON', () {
      final i = GroupCurriculumItem.fromJson({
        'id': 'it1',
        'text': 'Unit 1 Lesson 2',
        'note': 'qiyin',
        'order': 3,
        'covered': true,
        'coveredDate': '2026-08-03',
      });
      expect(i.id, 'it1');
      expect(i.text, 'Unit 1 Lesson 2');
      expect(i.note, 'qiyin');
      expect(i.order, 3);
      expect(i.covered, isTrue);
      expect(i.coveredDate, '2026-08-03');
    });
    test('bo\'sh JSON', () {
      final i = GroupCurriculumItem.fromJson({});
      expect(i.covered, isFalse);
      expect(i.coveredDate, '');
      expect(i.order, 0);
    });
  });

  group('GroupCurriculumTopic', () {
    test('to\'liq JSON', () {
      final t = GroupCurriculumTopic.fromJson({
        'id': 'tp1',
        'title': 'Unit 1',
        'note': '',
        'order': 1,
        'items': [
          {'id': 'it1', 'text': 'L1', 'covered': true}
        ],
      });
      expect(t.title, 'Unit 1');
      expect(t.items.single.covered, isTrue);
    });
    test('bo\'sh JSON', () {
      final t = GroupCurriculumTopic.fromJson({});
      expect(t.title, '');
      expect(t.items, isEmpty);
    });
  });

  group('GroupCurriculumLevel', () {
    test('to\'liq JSON', () {
      final l = GroupCurriculumLevel.fromJson({
        'id': 'lv1',
        'name': 'Beginner',
        'note': 'n',
        'order': 0,
        'topics': [
          {'id': 'tp1', 'title': 'Unit 1', 'items': []}
        ],
      });
      expect(l.name, 'Beginner');
      expect(l.topics.single.title, 'Unit 1');
    });
    test('bo\'sh JSON', () {
      final l = GroupCurriculumLevel.fromJson({});
      expect(l.name, '');
      expect(l.topics, isEmpty);
    });
  });

  group('GroupCurriculum', () {
    Map<String, dynamic> levelJson(String id) => {
          'id': id,
          'name': 'Level $id',
          'order': 1,
          'topics': [
            {
              'id': 'tp-$id',
              'title': 'Unit',
              'items': [
                {'id': 'it-$id', 'text': 'L1', 'covered': true}
              ]
            }
          ],
        };

    test('to\'liq JSON (modules bilan)', () {
      final c = GroupCurriculum.fromJson({
        'groupId': 'g1',
        'courseId': 'c1',
        'courseName': 'Ingliz tili',
        'totalItems': 120,
        'coveredCount': 45,
        'revisionLessons': 4,
        'totalLessons': 96,
        'remainingItems': 75,
        'estLessonsLeft': 60,
        'lessonsPerWeek': 3,
        'estFinishDate': '2027-01-15',
        'modules': [levelJson('m1')],
      });
      expect(c.groupId, 'g1');
      expect(c.courseName, 'Ingliz tili');
      expect(c.totalItems, 120);
      expect(c.coveredCount, 45);
      expect(c.revisionLessons, 4);
      expect(c.totalLessons, 96);
      expect(c.remainingItems, 75);
      expect(c.estLessonsLeft, 60);
      expect(c.lessonsPerWeek, 3);
      expect(c.estFinishDate, '2027-01-15');
      expect(c.levels.single.id, 'm1');
      expect(c.levels.single.topics.single.items.single.covered, isTrue);
    });
    test('bo\'sh JSON', () {
      final c = GroupCurriculum.fromJson({});
      expect(c.groupId, '');
      expect(c.totalItems, 0);
      expect(c.estFinishDate, isNull);
      expect(c.levels, isEmpty);
    });
    test('modules yo\'q → levels zaxira sifatida ishlatiladi', () {
      final c = GroupCurriculum.fromJson({
        'levels': [levelJson('lv1')]
      });
      expect(c.levels.single.id, 'lv1');
    });
    test('modules null → levels zaxira', () {
      final c = GroupCurriculum.fromJson({
        'modules': null,
        'levels': [levelJson('lv2')]
      });
      expect(c.levels.single.id, 'lv2');
    });
    test('modules ustunlik qiladi (ikkalasi ham bor)', () {
      final c = GroupCurriculum.fromJson({
        'modules': [levelJson('m9')],
        'levels': [levelJson('lv9')],
      });
      expect(c.levels.single.id, 'm9');
    });
    test('ikkalasi ham yo\'q → bo\'sh',
        () => expect(GroupCurriculum.fromJson({'modules': null, 'levels': null}).levels, isEmpty));
  });

  /* ==================================================================
   * 9. Profil, maktab, bildirishnomalar
   * ================================================================== */

  group('TeacherProfile', () {
    test('to\'liq JSON', () {
      final p = TeacherProfile.fromJson({
        'id': 't-1',
        'fullName': 'Ustoz Aka',
        'email': 'ustoz@example.com',
        'homeroomClass': 'Beginner A',
        'subjects': [
          {'id': 's1', 'name': 'Ingliz tili', 'price': 400000}
        ],
        'isSupport': false,
      });
      expect(p.id, 't-1');
      expect(p.fullName, 'Ustoz Aka');
      expect(p.email, 'ustoz@example.com');
      expect(p.homeroomClass, 'Beginner A');
      expect(p.subjects.single.name, 'Ingliz tili');
      expect(p.isSupport, isFalse);
    });
    test('bo\'sh JSON', () {
      final p = TeacherProfile.fromJson({});
      expect(p.id, '');
      expect(p.subjects, isEmpty);
      expect(p.isSupport, isNull);
    });
  });

  group('TeacherSchoolInfo', () {
    test('to\'liq JSON', () {
      final s = TeacherSchoolInfo.fromJson({'name': 'Intellect', 'telegramChannel': '@intellect'});
      expect([s.name, s.telegramChannel], ['Intellect', '@intellect']);
    });
    test('bo\'sh JSON', () {
      final s = TeacherSchoolInfo.fromJson({});
      expect([s.name, s.telegramChannel], ['', '']);
    });
  });

  group('AppNotification', () {
    test('to\'liq JSON', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'title': 'Yangi topshiriq',
        'body': 'Unit 3 topshirildi',
        'type': 'assignment',
        'createdAt': '2026-08-01T10:00:00Z',
        'read': true,
        'confirmed': false,
      });
      expect(n.id, 'n1');
      expect(n.title, 'Yangi topshiriq');
      expect(n.body, 'Unit 3 topshirildi');
      expect(n.type, 'assignment');
      expect(n.read, isTrue);
      expect(n.confirmed, isFalse);
    });
    test('bo\'sh JSON', () {
      final n = AppNotification.fromJson({});
      expect(n.read, isFalse);
      expect(n.confirmed, isFalse);
      expect(n.createdAt, '');
    });
  });

  group('NotificationsResponse', () {
    test('to\'liq JSON', () {
      final r = NotificationsResponse.fromJson({
        'unread': 3,
        'items': [
          {'id': 'n1', 'read': false},
          {'id': 'n2', 'read': true},
        ],
      });
      expect(r.unread, 3);
      expect(r.items, hasLength(2));
      expect(r.items.last.read, isTrue);
    });
    test('bo\'sh JSON', () {
      final r = NotificationsResponse.fromJson({});
      expect(r.unread, 0);
      expect(r.items, isEmpty);
    });
  });

  /* ==================================================================
   * 10. Reyting
   * ================================================================== */

  group('TeacherRatingRow', () {
    test('to\'liq JSON', () {
      final r = TeacherRatingRow.fromJson({
        'rank': 1,
        'studentId': 'st-1',
        'fullName': 'Ali',
        'groups': 'Guruh 1, Guruh 2',
        'journalTotal': 88,
        'criteriaDone': 30,
        'ball': 118,
        'average': 4.6,
        'attendance': 95.5,
      });
      expect(r.rank, 1);
      expect(r.groups, 'Guruh 1, Guruh 2');
      expect(r.journalTotal, 88);
      expect(r.criteriaDone, 30);
      expect(r.ball, 118);
      expect(r.average, 4.6);
      expect(r.attendance, 95.5);
    });
    test('bo\'sh JSON — attendance null', () {
      final r = TeacherRatingRow.fromJson({});
      expect(r.rank, 0);
      expect(r.ball, 0);
      expect(r.average, 0.0);
      expect(r.attendance, isNull);
    });
    test('attendance 0 → null emas',
        () => expect(TeacherRatingRow.fromJson({'attendance': 0}).attendance, 0.0));
  });

  group('TeacherRating', () {
    test('to\'liq JSON', () {
      final t = TeacherRating.fromJson({
        'teacherId': 't-1',
        'fullName': 'Ustoz',
        'groupsCount': 4,
        'studentsCount': 48,
        'averageBall': 92.3,
        'rows': [
          {'rank': 1, 'studentId': 'st-1'},
          {'rank': 2, 'studentId': 'st-2'},
        ],
      });
      expect(t.groupsCount, 4);
      expect(t.studentsCount, 48);
      expect(t.averageBall, 92.3);
      expect(t.rows.map((r) => r.rank), [1, 2]);
    });
    test('bo\'sh JSON', () {
      final t = TeacherRating.fromJson({});
      expect(t.groupsCount, 0);
      expect(t.rows, isEmpty);
    });
  });

  /* ==================================================================
   * 11. Testlar (online/offline)
   * ================================================================== */

  group('OnlineTest', () {
    test('const default konstruktor', () {
      const t = OnlineTest();
      expect(t.mode, 'offline');
      expect(t.pdfUrl, '');
      expect(t.pdfName, '');
      expect(t.questionCount, 0);
      expect(t.optionCount, 4);
      expect(t.answerKey, '');
      expect(t.startAt, '');
      expect(t.endAt, '');
      expect(t.isOnline, isFalse);
    });
    test('fromJson to\'liq (online)', () {
      final t = OnlineTest.fromJson({
        'mode': 'online',
        'pdfUrl': '/uploads/test.pdf',
        'pdfName': 'test.pdf',
        'questionCount': 30,
        'optionCount': 5,
        'answerKey': 'ABCDEABCDEABCDEABCDEABCDEABCDE',
        'startAt': '2026-08-05T09:00',
        'endAt': '2026-08-05T10:00',
      });
      expect(t.mode, 'online');
      expect(t.isOnline, isTrue);
      expect(t.pdfUrl, '/uploads/test.pdf');
      expect(t.pdfName, 'test.pdf');
      expect(t.questionCount, 30);
      expect(t.optionCount, 5);
      expect(t.answerKey.length, 30);
      expect(t.startAt, '2026-08-05T09:00');
      expect(t.endAt, '2026-08-05T10:00');
    });
    test('fromJson bo\'sh — mode "offline", optionCount 4', () {
      final t = OnlineTest.fromJson({});
      expect(t.mode, 'offline');
      expect(t.optionCount, 4);
      expect(t.isOnline, isFalse);
    });
    test('mode bo\'sh satr → "offline"',
        () => expect(OnlineTest.fromJson({'mode': ''}).mode, 'offline'));
    test('mode null → "offline"',
        () => expect(OnlineTest.fromJson({'mode': null}).mode, 'offline'));
    test('optionCount 0 → 4',
        () => expect(OnlineTest.fromJson({'optionCount': 0}).optionCount, 4));
    test('optionCount yaroqsiz satr → 4 (chunki _i → 0)',
        () => expect(OnlineTest.fromJson({'optionCount': 'x'}).optionCount, 4));
    test('optionCount 5 saqlanadi',
        () => expect(OnlineTest.fromJson({'optionCount': 5}).optionCount, 5));
    test('isOnline faqat aynan "online" da true', () {
      expect(OnlineTest.fromJson({'mode': 'online'}).isOnline, isTrue);
      expect(OnlineTest.fromJson({'mode': 'offline'}).isOnline, isFalse);
      expect(OnlineTest.fromJson({'mode': 'boshqa'}).isOnline, isFalse);
    });

    group('parse', () {
      test('null → default oflayn', () {
        final t = OnlineTest.parse(null);
        expect(t.mode, 'offline');
        expect(t.isOnline, isFalse);
      });
      test('bo\'sh map → default', () {
        final t = OnlineTest.parse(<String, dynamic>{});
        expect(t.mode, 'offline');
        expect(t.optionCount, 4);
      });
      test('Map<dynamic,dynamic> ham qabul qilinadi', () {
        final t = OnlineTest.parse(<dynamic, dynamic>{'mode': 'online', 'questionCount': 10});
        expect(t.isOnline, isTrue);
        expect(t.questionCount, 10);
      });
      test('satr → default', () => expect(OnlineTest.parse('online').mode, 'offline'));
      test('ro\'yxat → default', () => expect(OnlineTest.parse([1, 2]).mode, 'offline'));
      test('son → default', () => expect(OnlineTest.parse(5).optionCount, 4));
      test('bool → default', () => expect(OnlineTest.parse(true).isOnline, isFalse));
    });

    group('toJson', () {
      test('default → 10 ta kalit', () {
        final j = const OnlineTest().toJson();
        expect(j, {
          'mode': 'offline',
          'pdfUrl': '',
          'pdfName': '',
          'questionCount': 0,
          'optionCount': 4,
          'answerKey': '',
          'startAt': '',
          'endAt': '',
          // TEST KODI — markazdan tashqari ishtirokchi shu kod bilan kiradi.
          'code': '',
          // Standart: test guruhga ham e'lon qilinadi.
          'groupOpen': true,
        });
      });
      test('fromJson → toJson → fromJson aylanma o\'zgarmaydi', () {
        const src = {
          'mode': 'online',
          'pdfUrl': '/u/t.pdf',
          'pdfName': 't.pdf',
          'questionCount': 4,
          'optionCount': 5,
          'answerKey': 'ABCD',
          'startAt': '2026-08-05T09:00',
          'endAt': '2026-08-05T10:00',
          'code': 'K7M4QP',
          'groupOpen': false,
        };
        final once = OnlineTest.fromJson(src);
        final twice = OnlineTest.fromJson(once.toJson());
        expect(twice.toJson(), once.toJson());
        expect(twice.toJson(), src);
      });
      test('groupOpen berilmasa — guruhga OCHIQ (eski backend bilan moslik)', () {
        // Eski server `groupOpen` yubormaydi: testlar birdaniga "faqat kod" bo'lib
        // o'quvchilar ro'yxatidan yo'qolib qolmasligi kerak.
        expect(OnlineTest.fromJson(const {'mode': 'online'}).groupOpen, isTrue);
        expect(
            OnlineTest.fromJson(const {'mode': 'online', 'groupOpen': false}).groupOpen, isFalse);
      });
      test('parse(toJson()) aylanma', () {
        const t = OnlineTest(mode: 'online', questionCount: 2, answerKey: 'AB');
        final back = OnlineTest.parse(t.toJson());
        expect(back.mode, 'online');
        expect(back.questionCount, 2);
        expect(back.answerKey, 'AB');
      });
    });
  });

  group('GroupTest', () {
    test('to\'liq JSON (onlayn)', () {
      final t = GroupTest.fromJson({
        'id': 'gt-1',
        'groupId': 'g1',
        'name': 'Mid-term',
        'date': '2026-08-05',
        'maxScore': 30,
        'createdAt': '2026-08-01T10:00:00Z',
        'createdBy': 'Ustoz',
        'studentCount': 12,
        'scoredCount': 10,
        'avgScore': 24.5,
        'online': {'mode': 'online', 'questionCount': 30, 'optionCount': 5, 'answerKey': 'A' * 30},
        'submittedCount': 9,
      });
      expect(t.id, 'gt-1');
      expect(t.name, 'Mid-term');
      expect(t.maxScore, 30.0);
      expect(t.studentCount, 12);
      expect(t.scoredCount, 10);
      expect(t.avgScore, 24.5);
      expect(t.online.isOnline, isTrue);
      expect(t.online.optionCount, 5);
      expect(t.submittedCount, 9);
    });
    test('bo\'sh JSON — online default oflayn', () {
      final t = GroupTest.fromJson({});
      expect(t.id, '');
      expect(t.maxScore, 0.0);
      expect(t.avgScore, isNull);
      expect(t.online.mode, 'offline');
      expect(t.online.optionCount, 4);
      expect(t.submittedCount, 0);
    });
    test('online null → oflayn',
        () => expect(GroupTest.fromJson({'online': null}).online.isOnline, isFalse));
    test('avgScore 0 → null emas', () => expect(GroupTest.fromJson({'avgScore': 0}).avgScore, 0.0));
  });

  group('TestScoreRow', () {
    test('to\'liq JSON (botdan)', () {
      final r = TestScoreRow.fromJson({
        'studentId': 'st-1',
        'fullName': 'Ali',
        'score': 27,
        'rank': 1,
        'answers': 'ABCDA',
        'submittedAt': '2026-08-05T09:45',
        'source': 'bot',
      });
      expect(r.studentId, 'st-1');
      expect(r.score, 27.0);
      expect(r.rank, 1);
      expect(r.answers, 'ABCDA');
      expect(r.submittedAt, '2026-08-05T09:45');
      expect(r.source, 'bot');
      expect(r.fromBot, isTrue);
    });
    test('bo\'sh JSON', () {
      final r = TestScoreRow.fromJson({});
      expect(r.score, isNull);
      expect(r.rank, 0);
      expect(r.answers, '');
      expect(r.submittedAt, '');
      expect(r.source, '');
      expect(r.fromBot, isFalse);
    });
    test('fromBot: source="" → false',
        () => expect(TestScoreRow.fromJson({'source': ''}).fromBot, isFalse));
    test('fromBot: source="BOT" → false (aynan mos kelishi kerak)',
        () => expect(TestScoreRow.fromJson({'source': 'BOT'}).fromBot, isFalse));
    test('fromBot: source="manual" → false',
        () => expect(TestScoreRow.fromJson({'source': 'manual'}).fromBot, isFalse));
    test('fromBot: source=null → false',
        () => expect(TestScoreRow.fromJson({'source': null}).fromBot, isFalse));
    test('rank=0 → ball kiritilmagan qator',
        () => expect(TestScoreRow.fromJson({'rank': 0, 'score': null}).rank, 0));
    test('score satr sifatida', () => expect(TestScoreRow.fromJson({'score': '18.5'}).score, 18.5));
  });

  group('TestResultDetail', () {
    test('to\'liq JSON', () {
      final d = TestResultDetail.fromJson({
        'id': 'tr-1',
        'groupId': 'g1',
        'groupName': 'Beginner A',
        'name': 'Mid-term',
        'date': '2026-08-05',
        'maxScore': 30,
        'createdAt': '2026-08-01T10:00:00Z',
        'createdBy': 'Ustoz',
        'rows': [
          {'studentId': 'st-1', 'score': 28, 'rank': 1, 'source': 'bot'},
          {'studentId': 'st-2', 'score': 22, 'rank': 2, 'source': 'bot'},
          {'studentId': 'st-3', 'score': 20, 'rank': 3, 'source': ''},
        ],
        'online': {'mode': 'online', 'questionCount': 30},
      });
      expect(d.id, 'tr-1');
      expect(d.groupName, 'Beginner A');
      expect(d.maxScore, 30.0);
      expect(d.rows, hasLength(3));
      expect(d.online.isOnline, isTrue);
    });
    test('bo\'sh JSON', () {
      final d = TestResultDetail.fromJson({});
      expect(d.rows, isEmpty);
      expect(d.online.mode, 'offline');
      expect(d.submittedCount, 0);
      expect(d.externalRows, isEmpty);
    });
    test('MARKAZDAN TASHQARI ishtirokchilar alohida ro\'yxatda', () {
      final d = TestResultDetail.fromJson({
        'rows': [
          {'studentId': 'st-1', 'fullName': 'Azo', 'score': 20, 'rank': 1, 'source': 'bot'},
          // Boshqa guruh o'quvchisi — test KODI bilan qo'shilgan (member=false).
          {
            'studentId': 'st-9',
            'fullName': 'Boshqa guruhdan',
            'score': 25,
            'rank': 1,
            'source': 'bot',
            'member': false,
          },
        ],
        'externalRows': [
          {
            'id': 'ex-1',
            'fullName': 'Tashqi Bir',
            'phone': '998901112233',
            'score': 24,
            'rank': 1,
            'answers': 'ABCD',
            'submittedAt': '2026-08-05T10:00:00',
          },
          {'id': 'ex-2', 'fullName': 'Tashqi Ikki', 'score': 10, 'rank': 2},
        ],
      });
      // Markazdagilar — a'zo ham, kod bilan qo'shilgan markaz o'quvchisi ham shu ro'yxatda.
      expect(d.rows, hasLength(2));
      expect(d.rows[0].member, isTrue);
      expect(d.rows[1].member, isFalse);
      // Markazdan tashqari — alohida.
      expect(d.externalRows, hasLength(2));
      expect(d.externalRows[0].fullName, 'Tashqi Bir');
      expect(d.externalRows[0].phone, '998901112233');
      expect(d.externalRows[0].score, 24.0);
      expect(d.externalRows[1].rank, 2);
      expect(d.externalRows[1].phone, '');
      // submittedCount FAQAT markazdagi bot javoblarini sanaydi.
      expect(d.submittedCount, 2);
    });
    test('member berilmasa — a\'zo deb olinadi (eski backend bilan moslik)', () {
      final d = TestResultDetail.fromJson({
        'rows': [
          {'studentId': 'st-1'},
        ],
      });
      expect(d.rows.single.member, isTrue);
    });
    test('submittedCount — faqat source="bot"', () {
      final d = TestResultDetail.fromJson({
        'rows': [
          {'studentId': '1', 'source': 'bot'},
          {'studentId': '2', 'source': 'bot'},
          {'studentId': '3', 'source': ''},
          {'studentId': '4'},
          {'studentId': '5', 'source': 'manual'},
        ]
      });
      expect(d.submittedCount, 2);
    });
    test('submittedCount — hech kim bot emas', () {
      final d = TestResultDetail.fromJson({
        'rows': [
          {'studentId': '1'},
          {'studentId': '2', 'source': 'teacher'},
        ]
      });
      expect(d.submittedCount, 0);
    });
    test('submittedCount — hammasi botdan', () {
      final d = TestResultDetail.fromJson({
        'rows': List.generate(5, (i) => {'studentId': '$i', 'source': 'bot'})
      });
      expect(d.submittedCount, 5);
    });
    test('submittedCount rows bo\'sh bo\'lsa 0',
        () => expect(TestResultDetail.fromJson({'rows': []}).submittedCount, 0));
  });

  /* ==================================================================
   * 12. Shartnoma
   * ================================================================== */

  group('ContractDoc', () {
    test('to\'liq JSON', () {
      final c = ContractDoc.fromJson({
        'id': 'ct-1',
        'number': 12,
        'title': 'Shartnoma № 12',
        'target': 'staff',
        'recipientKey': 't-1',
        'recipientName': 'Ustoz Aka',
        'templateName': 'Mehnat shartnomasi',
        'date': '2026-01-15',
        'pdfUrl': '/uploads/ct-1.pdf',
        'docxUrl': '/uploads/ct-1.docx',
        'delivered': true,
        'status': 'signed',
        'visible': true,
      });
      expect(c.id, 'ct-1');
      expect(c.number, 12);
      expect(c.title, 'Shartnoma № 12');
      expect(c.target, 'staff');
      expect(c.recipientKey, 't-1');
      expect(c.recipientName, 'Ustoz Aka');
      expect(c.templateName, 'Mehnat shartnomasi');
      expect(c.date, '2026-01-15');
      expect(c.pdfUrl, '/uploads/ct-1.pdf');
      expect(c.docxUrl, '/uploads/ct-1.docx');
      expect(c.delivered, isTrue);
      expect(c.status, 'signed');
      expect(c.visible, isTrue);
    });
    test('bo\'sh JSON', () {
      final c = ContractDoc.fromJson({});
      expect(c.number, 0);
      expect(c.delivered, isFalse);
      expect(c.visible, isFalse);
      expect(c.pdfUrl, '');
    });
    test('number satr sifatida', () => expect(ContractDoc.fromJson({'number': '7'}).number, 7));
  });

  /* ==================================================================
   * 13. TASDIQLANGAN DEFEKTLAR (BUG-M1 .. BUG-M12)
   *
   * Har bir defekt uchun: (a) hozirgi xulqni qotiruvchi test,
   * (b) skip qilingan "to'g'ri xulq" testi.
   * ================================================================== */

  group('Tasdiqlangan defektlar', () {
    /* ---------------- BUG-M1 ---------------- */
    group('BUG-M1 (TUZATILDI) — GroupJournal.group majburiy cast', () {
      test('group yo\'q bo\'lsa bo\'sh GroupJournalInfo qaytadi', () {
        final j = GroupJournal.fromJson({'months': ['2026-08']});
        expect(j.group.id, '');
        expect(j.months, ['2026-08']);
      });
      test('group: null / Map bo\'lmagan qiymat ham yiqitmaydi', () {
        expect(GroupJournal.fromJson({'group': null}).group.id, '');
        expect(GroupJournal.fromJson({'group': 'g1'}).group.id, '');
        expect(GroupJournal.fromJson({'group': 42}).group.name, '');
      });
      test('String bo\'lmagan kalitli group ham yiqitmaydi', () {
        // Yangi qamrov: `_map` kalitlarni ham tekshiradi (BUG-M13 bilan bir xil qorovul).
        expect(GroupJournal.fromJson({'group': <dynamic, dynamic>{1: 'x'}}).group.id, '');
      });
      test('to\'g\'ri group hamon o\'qiladi', () {
        final j = GroupJournal.fromJson({
          'group': {'id': 'g1', 'name': 'A guruh'}
        });
        expect(j.group.id, 'g1');
        expect(j.group.name, 'A guruh');
      });
    });

    /* ---------------- BUG-M2 ---------------- */
    group('BUG-M2 (TUZATILDI) — _list buzuq elementni tashlab yuboradi', () {
      test('null elementlar tashlab yuboriladi', () {
        final r = EvaluationRow.fromJson({
          'reasons': [
            null,
            {'reasonId': 'r1'}
          ]
        });
        expect(r.reasons, hasLength(1));
        expect(r.reasons.single.reasonId, 'r1');
      });
      test('skalyar elementlar ham tashlab yuboriladi', () {
        expect(TeacherClass.fromJson({'subjects': [1]}).subjects, isEmpty);
        expect(TeacherClass.fromJson({'subjects': ['s1']}).subjects, isEmpty);
      });
      test('bitta buzuq element qolganini yo\'q qilmaydi', () {
        final m = PortalMeta.fromJson({
          'quarters': [
            {'quarter': 1},
            null,
            {'quarter': 2},
          ]
        });
        expect(m.quarters, hasLength(2));
        expect(m.quarters.map((q) => q.quarter), [1, 2]);
      });
    });

    /* ---------------- BUG-M3 ---------------- */
    group('BUG-M3 (TUZATILDI) — kollektsiya bo\'lmagan qiymat bo\'sh natija beradi', () {
      test('_intList: days = "1,3,5" → bo\'sh', () {
        expect(GroupJournalInfo.fromJson({'days': '1,3,5'}).days, isEmpty);
      });
      test('_strList: months = "" → bo\'sh', () {
        expect(EvaluationBoard.fromJson({'months': ''}).months, isEmpty);
      });
      test('_intMap: grades = [] / "" → bo\'sh', () {
        expect(EvaluationRow.fromJson({'grades': []}).grades, isEmpty);
        expect(EvaluationRow.fromJson({'grades': ''}).grades, isEmpty);
      });
      test('_list: subjects = {} (yakka Map) → bo\'sh', () {
        expect(TeacherClass.fromJson({'subjects': {'id': 's1'}}).subjects, isEmpty);
      });
      test('null hamon bo\'sh natija beradi (eski qorovul yutilgan)', () {
        expect(GroupJournalInfo.fromJson({'days': null}).days, isEmpty);
        expect(EvaluationBoard.fromJson({'months': null}).months, isEmpty);
        expect(EvaluationRow.fromJson({'grades': null}).grades, isEmpty);
        expect(TeacherClass.fromJson({'subjects': null}).subjects, isEmpty);
      });
    });

    /* ---------------- BUG-M4 ---------------- */
    group('BUG-M4 (TUZATILDI) — _sn bo\'sh satrni null ga aylantiradi', () {
      test('bo\'sh satr null bo\'ladi', () {
        expect(Assignment.fromJson({'dueDate': ''}).dueDate, isNull);
        expect(GroupCurriculum.fromJson({'estFinishDate': ''}).estFinishDate, isNull);
      });
      test('faqat probeldan iborat satr ham null', () {
        expect(Assignment.fromJson({'startDate': '   '}).startDate, isNull);
      });
      test('mazmunli satr o\'zgarmaydi (trim qilinmaydi)', () {
        expect(Assignment.fromJson({'dueDate': '2026-08-10'}).dueDate, '2026-08-10');
        expect(AssignmentMaterial.fromJson({'audioUrl': ' /a.mp3 '}).audioUrl, ' /a.mp3 ');
        expect(AssignmentMaterial.fromJson({'audioUrl': 7}).audioUrl, '7');
      });
    });

    /* ---------------- BUG-M5 ---------------- */
    group('BUG-M5 (TUZATILDI) — raqam parsing chegaralari', () {
      test('_i("4.0") → 4 (kasr shakldagi butun son double orqali o\'qiladi)', () {
        // BUG-M5 (TUZATILDI): `int.tryParse` yiqilsa `double.tryParse` zaxira yo'li bor.
        expect(TeacherClass.fromJson({'grade': '4.0'}).grade, 4);
        expect(GroupJournalInfo.fromJson({'days': ['1.0']}).days, [1]);
      });
      test('_i("12.5") → 13 (yaxlitlanadi, yo\'qolmaydi)', () {
        expect(TeacherClass.fromJson({'grade': '12.5'}).grade, 13);
      });
      test('_d("1,5") → 1.5 (vergulli kasr)', () {
        // BUG-M5 (TUZATILDI): o'zbek/rus klaviaturasidagi vergul nuqtaga o'giriladi.
        expect(Subject.fromJson({'price': '1,5'}).price, 1.5);
        expect(Subject.fromJson({'price': '-12,75'}).price, -12.75);
      });
      test('_i ham vergulli kasrni tushunadi', () {
        expect(TeacherClass.fromJson({'grade': '4,0'}).grade, 4);
      });
      // YANGI QAMROV: minglik guruh HAR DOIM 3 xonali, shuning uchun "1,234"
      // ATAYLAB kasr deb o'qilmaydi — aks holda 1234 so'm 1.234 so'mga aylanardi.
      test('_d("1,234") → 0.0 (minglik ajratgich kasr deb qabul qilinmaydi)', () {
        expect(Subject.fromJson({'price': '1,234'}).price, 0.0);
        expect(Subject.fromJson({'price': '1,2345'}).price, 0.0);
        expect(Subject.fromJson({'price': '1,234,567'}).price, 0.0);
      });
      test('_d("450 000") → 0.0 (probelli guruhlash hamon qo\'llanmaydi)', () {
        expect(Subject.fromJson({'price': '450 000'}).price, 0.0);
      });
    });

    /* ---------------- BUG-M6 ---------------- */
    group('BUG-M6 (TUZATILDI) — ro\'yxat ichidagi null tashlab yuboriladi', () {
      test('_strList: [null] → bo\'sh', () {
        // BUG-M6 (TUZATILDI): UI da so'zma-so'z "null" chiqmaydi.
        expect(Assignment.fromJson({'classIds': [null]}).classIds, isEmpty);
      });
      test('_strList: aralash ro\'yxatdan faqat null tushib qoladi', () {
        expect(Assignment.fromJson({'classNames': ['A', null, 'B']}).classNames, ['A', 'B']);
      });
      test('_intList: [null] → bo\'sh (fantom 0 kun yo\'q)', () {
        expect(GroupJournalInfo.fromJson({'days': [null]}).days, isEmpty);
        expect(GroupJournalInfo.fromJson({'days': [1, null, 3]}).days, [1, 3]);
      });
      test('_strList: doneKeys ichidagi null ham tashlanadi', () {
        expect(GradingBoardStudent.fromJson({'doneKeys': [null]}).doneKeys, isEmpty);
      });
    });

    /* ---------------- BUG-M7 ---------------- */
    group('BUG-M7 (TUZATILDI) — _b keng tarqalgan "rost" satrlarini tan oladi', () {
      test('"1" → true', () {
        // BUG-M7 (TUZATILDI): raqamli satr ham bool ga aylanadi.
        expect(AbsenceReason.fromJson({'isLate': '1'}).isLate, isTrue);
      });
      test('"yes"/"y"/"on" → true', () {
        expect(AbsenceReason.fromJson({'isLate': 'yes'}).isLate, isTrue);
        expect(AbsenceReason.fromJson({'isLate': 'Y'}).isLate, isTrue);
        expect(AbsenceReason.fromJson({'isLate': 'ON'}).isLate, isTrue);
      });
      test('"True " (probel bilan) → true', () {
        expect(AbsenceReason.fromJson({'isLate': 'True '}).isLate, isTrue);
      });
      test('"TRUE" (registrga bog\'liq emas)', () {
        expect(AbsenceReason.fromJson({'isLate': 'TRUE'}).isLate, isTrue);
      });
      test('notanish satr hamon false', () {
        expect(AbsenceReason.fromJson({'isLate': 'ha'}).isLate, isFalse);
        expect(AbsenceReason.fromJson({'isLate': '0'}).isLate, isFalse);
        expect(AbsenceReason.fromJson({'isLate': ''}).isLate, isFalse);
      });
    });

    /* ---------------- BUG-M8 ---------------- */
    group('BUG-M8 (TUZATILDI) — _bn bo\'sh satrni null ga aylantiradi', () {
      test('isSupport: "" → null ("ma\'lumot yo\'q")', () {
        // BUG-M8 (TUZATILDI): bo'sh satr endi "aniq false" emas.
        expect(TeacherProfile.fromJson({'isSupport': ''}).isSupport, isNull);
      });
      test('journalLinked: "   " → null', () {
        expect(SalaryLedger.fromJson({'journalLinked': '   '}).journalLinked, isNull);
      });
      test('"false" hamon ANIQ false (null emas)', () {
        expect(TeacherProfile.fromJson({'isSupport': 'false'}).isSupport, isFalse);
        expect(SalaryLedger.fromJson({'journalLinked': false}).journalLinked, isFalse);
      });
    });

    /* ---------------- BUG-M9 ---------------- */
    group('BUG-M9 (TUZATILDI) — GroupCurriculum: modules=[] bo\'lsa levels zaxira', () {
      Map<String, dynamic> lv(String id) => {
            'id': id,
            'name': 'L',
            'topics': [
              {
                'id': 't',
                'title': 'U',
                'items': [
                  {'id': 'i', 'text': 'x'}
                ]
              }
            ],
          };

      test('modules: [] + to\'ldirilgan levels → levels zaxira sifatida o\'qiladi', () {
        // BUG-M9 (TUZATILDI): `??` o'rniga "bo'sh bo'lmagan ro'yxat" tekshiruvi.
        final c = GroupCurriculum.fromJson({
          'modules': [],
          'levels': [lv('lv1'), lv('lv2')],
        });
        expect(c.levels, hasLength(2));
        expect(c.levels.first.id, 'lv1');
      });
      test('modules: [] + levels: [] → bo\'sh', () {
        expect(GroupCurriculum.fromJson({'modules': [], 'levels': []}).levels, isEmpty);
      });
      test('modules yo\'q bo\'lsa ham levels o\'qiladi', () {
        expect(GroupCurriculum.fromJson({'levels': [lv('lv1')]}).levels, hasLength(1));
      });
      test('to\'ldirilgan modules levels\'dan ustun turadi', () {
        final c = GroupCurriculum.fromJson({
          'modules': [lv('m1')],
          'levels': [lv('lv1'), lv('lv2')],
        });
        expect(c.levels.single.id, 'm1');
      });
    });

    /* ---------------- BUG-M10 (optionCount + mode) ---------------- */
    group('BUG-M10 (TUZATILDI) — OnlineTest: optionCount qisiladi, mode normallashadi', () {
      test('optionCount = -3 → 2 (pastki chegara)', () {
        // BUG-M10 (TUZATILDI): `clamp(2, 6)` — `group_tests_panel.dart` dagi
        // variantlar dropdowni faqat shu oraliqni biladi, aks holda assert.
        expect(OnlineTest.fromJson({'optionCount': -3}).optionCount, 2);
      });
      test('optionCount = 99 → 6 (yuqori chegara)', () {
        expect(OnlineTest.fromJson({'optionCount': 99}).optionCount, 6);
      });
      test('optionCount berilmagan / 0 → 4 (A–D standarti)', () {
        expect(OnlineTest.fromJson({}).optionCount, 4);
        expect(OnlineTest.fromJson({'optionCount': 0}).optionCount, 4);
      });
      test('oraliq ichidagi qiymat tegilmaydi', () {
        expect(OnlineTest.fromJson({'optionCount': 2}).optionCount, 2);
        expect(OnlineTest.fromJson({'optionCount': 5}).optionCount, 5);
        expect(OnlineTest.fromJson({'optionCount': 6}).optionCount, 6);
      });
      test('mode = "ONLINE" → isOnline true', () {
        // BUG-M10 (TUZATILDI): `mode` registr/probeldan qat'i nazar o'qiladi.
        final t = OnlineTest.fromJson({'mode': 'ONLINE'});
        expect(t.mode, 'online');
        expect(t.isOnline, isTrue);
      });
      test('mode = " online " → isOnline true', () {
        expect(OnlineTest.fromJson({'mode': ' online '}).isOnline, isTrue);
      });
      test('mode bo\'sh / berilmagan → "offline"', () {
        expect(OnlineTest.fromJson({}).mode, 'offline');
        expect(OnlineTest.fromJson({'mode': '   '}).mode, 'offline');
        expect(OnlineTest.fromJson({'mode': ''}).isOnline, isFalse);
      });
    });

    /* ------- BUG-M10 ning QOLGAN qismi (ataylab tuzatilmagan) ------- */
    // `answerKey` uzunligi `questionCount` ga ATAYLAB moslashtirilmaydi:
    // tahrirlash oynasi uni o'zi to'g'rilaydi va barcha sikllar
    // `answerKey.length` bo'yicha aylanadi (models.dart:1547 izohi).
    group('BUG-M10 — answerKey/questionCount hamon validatsiya qilinmaydi', () {
      test('answerKey questionCount dan qisqa bo\'lishi mumkin', () {
        final t = OnlineTest.fromJson({'mode': 'online', 'questionCount': 30, 'answerKey': 'ABC'});
        expect(t.questionCount, 30);
        expect(t.answerKey.length, 3);
      });
      test('answerKey questionCount dan uzun bo\'lishi mumkin', () {
        final t = OnlineTest.fromJson({'mode': 'online', 'questionCount': 2, 'answerKey': 'ABCDE'});
        expect(t.answerKey.length, 5);
      });
      test('questionCount manfiy ham o\'tadi', () {
        expect(OnlineTest.fromJson({'questionCount': -5}).questionCount, -5);
      });
      test('answerKey questionCount ga moslashtirilishi kerak', () {
        final t = OnlineTest.fromJson({'mode': 'online', 'questionCount': 2, 'answerKey': 'ABCDE'});
        expect(t.answerKey.length, t.questionCount);
      }, skip: _skipReason('BUG-M10'));
    });

    /* ---------------- BUG-M11 ---------------- */
    group('BUG-M11 — toJson ixtiyoriy maydonlarni null bilan yuboradi', () {
      test('MaterialInput.toJson: audioUrl null bo\'lsa ham kalit bor', () {
        // BUG-M11: models.dart:292-298 — kalit tashlab ketilmaydi, `null` yuboriladi.
        final j = MaterialInput(name: 'a', url: 'u', size: 1, contentType: 'ct').toJson();
        expect(j.containsKey('audioUrl'), isTrue);
        expect(j['audioUrl'], isNull);
      });
      test('SaveAssignmentInput.toJson: barcha ixtiyoriylar null bo\'lib qoladi', () {
        // BUG-M11: models.dart:382-397 — description/startDate/dueDate/referenceText null yuboriladi.
        final j = SaveAssignmentInput(
          subjectId: 's',
          title: 't',
          format: 'written',
          classIds: const [],
          lateAccept: false,
          latePenaltyPct: 0,
          maxScore: 0,
          autoGrade: false,
          materials: const [],
          questions: const [],
        ).toJson();
        expect(j['description'], isNull);
        expect(j['startDate'], isNull);
        expect(j['dueDate'], isNull);
        expect(j['referenceText'], isNull);
        expect(j.keys, hasLength(14));
      });
      test('null ixtiyoriy maydonlar JSON dan tushib qolishi kerak', () {
        final m = MaterialInput(name: 'a', url: 'u', size: 1, contentType: 'ct').toJson();
        expect(m.containsKey('audioUrl'), isFalse);

        final s = SaveAssignmentInput(
          subjectId: 's',
          title: 't',
          format: 'written',
          classIds: const [],
          lateAccept: false,
          latePenaltyPct: 0,
          maxScore: 0,
          autoGrade: false,
          materials: const [],
          questions: const [],
        ).toJson();
        expect(s.containsKey('description'), isFalse);
        expect(s.containsKey('referenceText'), isFalse);
      }, skip: _skipReason('BUG-M11'));
    });

    /* ---------------- BUG-M12 ---------------- */
    group('BUG-M12 (TUZATILDI) — _d/_dn NaN va cheksizlikni rad etadi', () {
      test('price: "NaN" → 0.0', () {
        // BUG-M12 (TUZATILDI): `fmtMoney`/`gradeColor` build ichida
        // `UnsupportedError` bermasligi uchun manbada filtrlanadi.
        expect(Subject.fromJson({'price': 'NaN'}).price, 0.0);
      });
      test('price: "Infinity" → 0.0', () {
        expect(Subject.fromJson({'price': 'Infinity'}).price, 0.0);
      });
      test('maxScore: "-Infinity" → 0.0', () {
        expect(Assignment.fromJson({'maxScore': '-Infinity'}).maxScore, 0.0);
      });
      test('_dn: score "NaN"/"Infinity" → null', () {
        expect(SubmissionRow.fromJson({'score': 'NaN'}).score, isNull);
        expect(SubmissionRow.fromJson({'score': '-Infinity'}).score, isNull);
      });
      test('num turidagi NaN/cheksizlik ham filtrlanadi (faqat satr emas)', () {
        expect(Subject.fromJson({'price': double.nan}).price, 0.0);
        expect(Subject.fromJson({'price': double.infinity}).price, 0.0);
        expect(SubmissionRow.fromJson({'score': double.nan}).score, isNull);
      });
      test('_i/_in ham cheksiz num ni rad etadi', () {
        expect(TeacherClass.fromJson({'grade': double.infinity}).grade, 0);
        expect(TeacherClass.fromJson({'grade': double.nan}).grade, 0);
      });
    });
  });

  /* ==================================================================
   * 14. Testlar yozish vaqtida TOPILGAN yangi defektlar (BUG-M13..M15)
   * ================================================================== */

  group('Yangi topilgan defektlar', () {
    /* ---------------- BUG-M13 ---------------- */
    group('BUG-M13 (TUZATILDI) — OnlineTest.parse buzuq Map ni yutadi', () {
      test('String bo\'lmagan kalitli Map → default oflayn test', () {
        // BUG-M13 (TUZATILDI): `_map` kalitlarni ham tekshiradi, `Map<String,
        // dynamic>.from` endi ishlatilmaydi — testlar ekrani yiqilmaydi.
        final t = OnlineTest.parse(<dynamic, dynamic>{1: 'x'});
        expect(t.mode, 'offline');
        expect(t.isOnline, isFalse);
      });
      test('GroupTest.online orqali ham yiqilmaydi', () {
        final t = GroupTest.fromJson({'online': <dynamic, dynamic>{1: 'x'}});
        expect(t.online.mode, 'offline');
      });
      test('Map<dynamic,dynamic> to\'g\'ri kalitlar bilan hamon o\'qiladi', () {
        final t = OnlineTest.parse(<dynamic, dynamic>{'mode': 'online', 'questionCount': 10});
        expect(t.isOnline, isTrue);
        expect(t.questionCount, 10);
      });
      test('Map bo\'lmagan qiymat — oflayn (eski xulq saqlangan)', () {
        expect(OnlineTest.parse(null).mode, 'offline');
        expect(OnlineTest.parse('online').mode, 'offline');
      });
    });

    /* ---------------- BUG-M14 ---------------- */
    group('BUG-M14 (TUZATILDI) — _intMap String bo\'lmagan kalitni satrga aylantiradi', () {
      test('grades: {1: 5} → {"1": 5}', () {
        // BUG-M14 (TUZATILDI): raqamli kalit odatda o'quvchi/mezon id si —
        // tashlab yuborish ma'lumot yo'qotish bo'lardi.
        expect(EvaluationRow.fromJson({'grades': <dynamic, dynamic>{1: 5}}).grades, {'1': 5});
      });
      test('aralash kalitlar ham saqlanadi', () {
        expect(
          EvaluationRow.fromJson({'grades': <dynamic, dynamic>{1: 5, 'cr2': '4'}}).grades,
          {'1': 5, 'cr2': 4},
        );
      });
    });

    /* ---------------- BUG-M15 ---------------- */
    group('BUG-M15 (TUZATILDI) — _d toshgan raqamli satrni 0.0 ga aylantiradi', () {
      test('price: "1e400" → 0.0', () {
        // BUG-M15 (TUZATILDI): "Infinity" so'zi bo'lmasa ham natija cheksiz
        // bo'lsa rad etiladi.
        expect(Subject.fromJson({'price': '1e400'}).price, 0.0);
      });
      test('_dn: "1e400" → null', () {
        expect(SubmissionRow.fromJson({'score': '1e400'}).score, isNull);
      });
      test('_i: "1e400" → 0', () {
        expect(TeacherClass.fromJson({'grade': '1e400'}).grade, 0);
      });
      // TUZATILDI: avval `double` zaxira yo'li `round()` da maksimal int ga
      // to'yinar edi va baho `9223372036854775807` bo'lib qolardi — bu 0 dan
      // ham yomonroq. Endi 2^53 dan katta qiymat buzuq deb hisoblanadi.
      test('int64 chegarasidan oshgan satr → 0', () {
        expect(TeacherClass.fromJson({'grade': '9223372036854775808'}).grade, 0);
      });
      test('2^53 dan katta double satr → 0', () {
        expect(TeacherClass.fromJson({'grade': '1e17'}).grade, 0);
      });
      // Chegara ichidagi qiymat hamon o'tadi (id/son maydonlari uchun muhim).
      test('2^53 ichidagi kasr shakl → yaxlitlanadi', () {
        expect(TeacherClass.fromJson({'grade': '4.0'}).grade, 4);
      });
    });
  });
}
