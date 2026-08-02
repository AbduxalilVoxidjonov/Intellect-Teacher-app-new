// Backend (IntellectCRM) bilan bir xil shakldagi modellar — teacher.ts, journal.ts,
// grading.ts, curriculum.ts, assignments.ts (IntellectCRM.Client/src/api/services) dan.
// Faqat o'qituvchi (teacher) portali uchun kerakli tiplar.

/* ---------- Xavfsiz parsing yordamchilari ---------- */

String _s(dynamic v) => v == null ? '' : v.toString();

/// Bo'sh yoki faqat probeldan iborat satr = "ma'lumot yo'q" → `null`.
/// Aks holda UI `dueDate != null` ni "sana bor" deb o'qiydi va bo'sh joy chizadi.
String? _sn(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.trim().isEmpty ? null : s;
}

/// Faqat aniq vergulli kasr ("1,5", "-12,75") nuqtali shaklga o'giriladi.
/// Minglik guruh HAR DOIM 3 xonali ("1,234") — shuning uchun 1..2 xonali
/// naqsh bilan chalkashmaydi va u tegilmay qoladi (0.0 bo'lib qolaveradi).
final RegExp _decimalCommaRe = RegExp(r'^-?\d+,\d{1,2}$');

String _commaToDot(String s) {
  final t = s.trim();
  return _decimalCommaRe.hasMatch(t) ? t.replaceFirst(',', '.') : s;
}

/// `num`/`double` oqimidagi NaN va cheksizlik UI ga o'tsa `fmtMoney`/`gradeColor`
/// `build()` ichida `UnsupportedError` beradi — shuning uchun manbada filtrlanadi.
double? _finite(double? d) => (d != null && d.isFinite) ? d : null;

/// `double` dan `int` ga xavfsiz o'tish. `9.2e18` kabi qiymat `.round()` da
/// int64 chegarasiga "yopishib" qolardi va baho `9223372036854775807` bo'lardi —
/// bu 0 dan ham yomonroq. 2^53 dan katta son aniq buzuq ma'lumot.
int? _finiteInt(double? d) {
  final v = _finite(d);
  if (v == null || v.abs() > 9007199254740992.0) return null;
  return v.round();
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.toInt() : 0;
  final s = v.toString();
  // "4.0" kabi kasr shaklidagi butun son int.tryParse uchun yaroqsiz — baho
  // yo'qolmasligi uchun double orqali zaxira yo'l bor.
  return int.tryParse(s) ?? _finiteInt(double.tryParse(_commaToDot(s))) ?? 0;
}

int? _in(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.toInt() : null;
  final s = v.toString();
  return int.tryParse(s) ?? _finiteInt(double.tryParse(_commaToDot(s)));
}

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.isFinite ? v.toDouble() : 0;
  return _finite(double.tryParse(_commaToDot(v.toString()))) ?? 0;
}

double? _dn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  return _finite(double.tryParse(_commaToDot(v.toString())));
}

bool _b(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes' || s == 'y' || s == 'on';
  }
  return false;
}

/// Bo'sh satr — "ma'lumot yo'q", "aniq false" emas.
bool? _bn(dynamic v) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;
  return _b(v);
}

/// Har doim `Map<String, dynamic>` qaytaradi: Map bo'lmasa — bo'sh map
/// (barcha `fromJson` bo'sh map bilan ishlay oladi).
///
/// Kalit String bo'lmasa `toString()` bilan saqlanadi — `_intMap` va
/// `teacher_api.dart::_asMap` bilan BIR XIL qoida. Avval bunday map butunlay
/// tashlab yuborilardi, ya'ni bitta raqamli kalit qolgan hamma maydonni
/// (masalan `group.id` ni) yo'q qilardi.
Map<String, dynamic> _map(dynamic v) {
  if (v is! Map) return const <String, dynamic>{};
  final out = <String, dynamic>{};
  v.forEach((k, val) => out[k.toString()] = val);
  return out;
}

/// `a` to'ldirilgan ro'yxat bo'lsa o'sha, aks holda `b` (zaxira maydon).
dynamic _orFallback(dynamic a, dynamic b) => (a is List && a.isNotEmpty) ? a : b;

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) {
  if (v is! List) return <T>[];
  // Bitta buzuq element (null yoki skalyar) butun javobni yo'q qilmasligi kerak.
  // `_map` ishlatiladi: `Map<String, dynamic>.from` String bo'lmagan kalitda
  // yiqilardi, ya'ni bitta buzuq element hamon butun ro'yxatni yo'q qilardi.
  return v.whereType<Map>().map((e) => fromJson(_map(e))).toList();
}

List<String> _strList(dynamic v) {
  if (v is! List) return <String>[];
  return v.where((e) => e != null).map((e) => e.toString()).toList();
}

List<int> _intList(dynamic v) {
  if (v is! List) return <int>[];
  return v.where((e) => e != null).map((e) => _i(e)).toList();
}

Map<String, int> _intMap(dynamic v) {
  if (v is! Map) return <String, int>{};
  // Kalit String bo'lmasa `toString()` bilan saqlanadi: raqamli kalit ({1: 5})
  // odatda o'quvchi/mezon id si — uni tashlab yuborish ma'lumot yo'qotish bo'lardi.
  return v.map((k, val) => MapEntry(_s(k), _i(val)));
}


/* ---------- Kurslar (fanlar) ---------- */

class Subject {
  final String id;
  final String name;
  /** Kurs narxi (so'm) */
  final double price;
  /** Bir dars uchun yaxlit narx (so'm), 0/null = kiritilmagan */
  final double? lessonPrice;

  Subject({required this.id, required this.name, required this.price, this.lessonPrice});

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: _s(j['id']),
        name: _s(j['name']),
        price: _d(j['price']),
        lessonPrice: _dn(j['lessonPrice']),
      );
}

/* ---------- O'qituvchi dars beradigan guruh ---------- */

class TeacherClass {
  final String classId;
  final String className;
  final int grade;
  final List<Subject> subjects;

  TeacherClass({
    required this.classId,
    required this.className,
    required this.grade,
    required this.subjects,
  });

  factory TeacherClass.fromJson(Map<String, dynamic> j) => TeacherClass(
        classId: _s(j['classId']),
        className: _s(j['className']),
        grade: _i(j['grade']),
        subjects: _list(j['subjects'], Subject.fromJson),
      );
}

/* ---------- O'quvchilarni baholash (o'qituvchi o'z fanidan) ---------- */

class EvaluationType {
  final String id;
  final String name;
  final String description;

  EvaluationType({required this.id, required this.name, required this.description});

  factory EvaluationType.fromJson(Map<String, dynamic> j) => EvaluationType(
        id: _s(j['id']),
        name: _s(j['name']),
        description: _s(j['description']),
      );
}

class AttendanceReasonCount {
  final String reasonId;
  final String name;
  final String short;
  final bool isLate;
  final int count;

  AttendanceReasonCount({
    required this.reasonId,
    required this.name,
    required this.short,
    required this.isLate,
    required this.count,
  });

  factory AttendanceReasonCount.fromJson(Map<String, dynamic> j) => AttendanceReasonCount(
        reasonId: _s(j['reasonId']),
        name: _s(j['name']),
        short: _s(j['short']),
        isLate: _b(j['isLate']),
        count: _i(j['count']),
      );
}

class EvaluationRow {
  final String studentId;
  final String fullName;
  final String className;
  /** O'tilgan darslar soni */
  final int conducted;
  /** Qatnashgan darslar */
  final int attended;
  final List<AttendanceReasonCount> reasons;
  /** Baholash turi id -> baho (1-5) */
  final Map<String, int> grades;
  final double avgGrade;

  EvaluationRow({
    required this.studentId,
    required this.fullName,
    required this.className,
    required this.conducted,
    required this.attended,
    required this.reasons,
    required this.grades,
    required this.avgGrade,
  });

  factory EvaluationRow.fromJson(Map<String, dynamic> j) => EvaluationRow(
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        className: _s(j['className']),
        conducted: _i(j['conducted']),
        attended: _i(j['attended']),
        reasons: _list(j['reasons'], AttendanceReasonCount.fromJson),
        grades: _intMap(j['grades']),
        avgGrade: _d(j['avgGrade']),
      );
}

/** {id, name} ko'rinishidagi ma'lumotnoma (EvaluationBoard.subjects/groups). */
class IdNameOption {
  final String id;
  final String name;

  IdNameOption({required this.id, required this.name});

  factory IdNameOption.fromJson(Map<String, dynamic> j) =>
      IdNameOption(id: _s(j['id']), name: _s(j['name']));
}

class EvaluationBoard {
  final List<String> months;
  final String month;
  final int week;
  final List<EvaluationType> types;
  final List<EvaluationRow> rows;
  final String? subjectId;
  final List<IdNameOption>? subjects;
  final List<IdNameOption>? groups;
  final String? groupId;

  EvaluationBoard({
    required this.months,
    required this.month,
    required this.week,
    required this.types,
    required this.rows,
    this.subjectId,
    this.subjects,
    this.groups,
    this.groupId,
  });

  factory EvaluationBoard.fromJson(Map<String, dynamic> j) => EvaluationBoard(
        months: _strList(j['months']),
        month: _s(j['month']),
        week: _i(j['week']),
        types: _list(j['types'], EvaluationType.fromJson),
        rows: _list(j['rows'], EvaluationRow.fromJson),
        subjectId: _sn(j['subjectId']),
        subjects: j['subjects'] == null ? null : _list(j['subjects'], IdNameOption.fromJson),
        groups: j['groups'] == null ? null : _list(j['groups'], IdNameOption.fromJson),
        groupId: _sn(j['groupId']),
      );
}

/* ---------- Topshiriqlar ---------- */

/** 'written' | 'file' | 'test' | 'video' | 'speaking' */
typedef AssignmentFormat = String;

/** Topshiriqqa biriktirilgan material (server qaytargan, id bilan) */
class AssignmentMaterial {
  final String id;
  final String name;
  final String url;
  final int size;
  final String contentType;
  final String? audioUrl;

  AssignmentMaterial({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.contentType,
    this.audioUrl,
  });

  factory AssignmentMaterial.fromJson(Map<String, dynamic> j) => AssignmentMaterial(
        id: _s(j['id']),
        name: _s(j['name']),
        url: _s(j['url']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
        audioUrl: _sn(j['audioUrl']),
      );
}

/** Topshiriq materiali kiritmasi (yuklangach metadata; id yo'q) */
class MaterialInput {
  final String name;
  final String url;
  final int size;
  final String contentType;
  final String? audioUrl;

  MaterialInput({
    required this.name,
    required this.url,
    required this.size,
    required this.contentType,
    this.audioUrl,
  });

  factory MaterialInput.fromJson(Map<String, dynamic> j) => MaterialInput(
        name: _s(j['name']),
        url: _s(j['url']),
        size: _i(j['size']),
        contentType: _s(j['contentType']),
        audioUrl: _sn(j['audioUrl']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'size': size,
        'contentType': contentType,
        'audioUrl': audioUrl,
      };
}

/** Test savoli (server qaytargan, id bilan) */
class TestQuestion {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int order;

  TestQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.order,
  });

  factory TestQuestion.fromJson(Map<String, dynamic> j) => TestQuestion(
        id: _s(j['id']),
        text: _s(j['text']),
        options: _strList(j['options']),
        correctIndex: _i(j['correctIndex']),
        order: _i(j['order']),
      );
}

/** Test savoli kiritmasi (id yo'q) */
class QuestionInput {
  final String text;
  final List<String> options;
  final int correctIndex;

  QuestionInput({required this.text, required this.options, required this.correctIndex});

  factory QuestionInput.fromJson(Map<String, dynamic> j) => QuestionInput(
        text: _s(j['text']),
        options: _strList(j['options']),
        correctIndex: _i(j['correctIndex']),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'options': options,
        'correctIndex': correctIndex,
      };
}

/** Topshiriq yaratish/tahrirlash kiritmasi */
class SaveAssignmentInput {
  final String subjectId;
  final String title;
  final String? description;
  final AssignmentFormat format;
  final List<String> classIds;
  final String? startDate;
  final String? dueDate;
  final bool lateAccept;
  final double latePenaltyPct;
  final double maxScore;
  final bool autoGrade;
  final List<MaterialInput> materials;
  final List<QuestionInput> questions;
  /** Speaking (format=speaking) uchun o'qiladigan matn */
  final String? referenceText;

  SaveAssignmentInput({
    required this.subjectId,
    required this.title,
    this.description,
    required this.format,
    required this.classIds,
    this.startDate,
    this.dueDate,
    required this.lateAccept,
    required this.latePenaltyPct,
    required this.maxScore,
    required this.autoGrade,
    required this.materials,
    required this.questions,
    this.referenceText,
  });

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'title': title,
        'description': description,
        'format': format,
        'classIds': classIds,
        'startDate': startDate,
        'dueDate': dueDate,
        'lateAccept': lateAccept,
        'latePenaltyPct': latePenaltyPct,
        'maxScore': maxScore,
        'autoGrade': autoGrade,
        'materials': materials.map((m) => m.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'referenceText': referenceText,
      };
}

/** Topshiriq/test (boy model) */
class Assignment {
  final String id;
  final String createdByUserId;
  final String subjectId;
  final String subjectName;
  final String title;
  final String description;
  final AssignmentFormat format;
  final List<String> classIds;
  final List<String> classNames;
  final String? startDate;
  final String? dueDate;
  final bool lateAccept;
  final double latePenaltyPct;
  final double maxScore;
  final bool autoGrade;
  final String createdAt;
  final List<AssignmentMaterial> materials;
  final List<TestQuestion> questions;
  final String? referenceText;

  Assignment({
    required this.id,
    required this.createdByUserId,
    required this.subjectId,
    required this.subjectName,
    required this.title,
    required this.description,
    required this.format,
    required this.classIds,
    required this.classNames,
    this.startDate,
    this.dueDate,
    required this.lateAccept,
    required this.latePenaltyPct,
    required this.maxScore,
    required this.autoGrade,
    required this.createdAt,
    required this.materials,
    required this.questions,
    this.referenceText,
  });

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: _s(j['id']),
        createdByUserId: _s(j['createdByUserId']),
        subjectId: _s(j['subjectId']),
        subjectName: _s(j['subjectName']),
        title: _s(j['title']),
        description: _s(j['description']),
        format: _s(j['format']),
        classIds: _strList(j['classIds']),
        classNames: _strList(j['classNames']),
        startDate: _sn(j['startDate']),
        dueDate: _sn(j['dueDate']),
        lateAccept: _b(j['lateAccept']),
        latePenaltyPct: _d(j['latePenaltyPct']),
        maxScore: _d(j['maxScore']),
        autoGrade: _b(j['autoGrade']),
        createdAt: _s(j['createdAt']),
        materials: _list(j['materials'], AssignmentMaterial.fromJson),
        questions: _list(j['questions'], TestQuestion.fromJson),
        referenceText: _sn(j['referenceText']),
      );
}

class AssignmentType {
  final String id;
  final String name;

  AssignmentType({required this.id, required this.name});

  factory AssignmentType.fromJson(Map<String, dynamic> j) =>
      AssignmentType(id: _s(j['id']), name: _s(j['name']));
}

/** Topshiriq natijasi — bitta o'quvchining holati */
class SubmissionRow {
  final String studentId;
  final String studentName;
  final String className;
  final bool completed;
  final String? submittedAt;
  final double? score;
  final String? answerText;
  final String? fileUrl;

  SubmissionRow({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.completed,
    this.submittedAt,
    this.score,
    this.answerText,
    this.fileUrl,
  });

  factory SubmissionRow.fromJson(Map<String, dynamic> j) => SubmissionRow(
        studentId: _s(j['studentId']),
        studentName: _s(j['studentName']),
        className: _s(j['className']),
        completed: _b(j['completed']),
        submittedAt: _sn(j['submittedAt']),
        score: _dn(j['score']),
        answerText: _sn(j['answerText']),
        fileUrl: _sn(j['fileUrl']),
      );
}

/** Topshiriq bo'yicha natijalar (kim bajardi/bajarmadi) */
class AssignmentResult {
  final String assignmentId;
  final String title;
  final AssignmentFormat format;
  final double maxScore;
  final int total;
  final int completedCount;
  final List<SubmissionRow> rows;

  AssignmentResult({
    required this.assignmentId,
    required this.title,
    required this.format,
    required this.maxScore,
    required this.total,
    required this.completedCount,
    required this.rows,
  });

  factory AssignmentResult.fromJson(Map<String, dynamic> j) => AssignmentResult(
        assignmentId: _s(j['assignmentId']),
        title: _s(j['title']),
        format: _s(j['format']),
        maxScore: _d(j['maxScore']),
        total: _i(j['total']),
        completedCount: _i(j['completedCount']),
        rows: _list(j['rows'], SubmissionRow.fromJson),
      );
}

/* ---------- Xabarlar (guruh chati) ---------- */

class ChatMessage {
  final String id;
  final String className;
  final String senderUserId;
  final String senderName;
  /** admin | teacher | student | ... (Role) */
  final String senderRole;
  final String text;
  final String createdAt;

  ChatMessage({
    required this.id,
    required this.className,
    required this.senderUserId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: _s(j['id']),
        className: _s(j['className']),
        senderUserId: _s(j['senderUserId']),
        senderName: _s(j['senderName']),
        senderRole: _s(j['senderRole']),
        text: _s(j['text']),
        createdAt: _s(j['createdAt']),
      );
}

/* ---------- Portal meta (choraklar, davomat sabablari) ---------- */

class QuarterPeriod {
  final int quarter;
  final String startDate;
  final String endDate;
  final bool gradesOpen;

  QuarterPeriod({
    required this.quarter,
    required this.startDate,
    required this.endDate,
    required this.gradesOpen,
  });

  factory QuarterPeriod.fromJson(Map<String, dynamic> j) => QuarterPeriod(
        quarter: _i(j['quarter']),
        startDate: _s(j['startDate']),
        endDate: _s(j['endDate']),
        gradesOpen: _b(j['gradesOpen']),
      );
}

class AbsenceReason {
  final String id;
  final String name;
  final String short;
  final bool isLate;

  AbsenceReason({
    required this.id,
    required this.name,
    required this.short,
    required this.isLate,
  });

  factory AbsenceReason.fromJson(Map<String, dynamic> j) => AbsenceReason(
        id: _s(j['id']),
        name: _s(j['name']),
        short: _s(j['short']),
        isLate: _b(j['isLate']),
      );
}

class PortalMeta {
  final List<QuarterPeriod> quarters;
  final List<AbsenceReason> absenceReasons;
  final int currentQuarter;
  final int currentWeek;

  PortalMeta({
    required this.quarters,
    required this.absenceReasons,
    required this.currentQuarter,
    required this.currentWeek,
  });

  factory PortalMeta.fromJson(Map<String, dynamic> j) => PortalMeta(
        quarters: _list(j['quarters'], QuarterPeriod.fromJson),
        absenceReasons: _list(j['absenceReasons'], AbsenceReason.fromJson),
        currentQuarter: _i(j['currentQuarter']),
        currentWeek: _i(j['currentWeek']),
      );
}

/* ---------- Maosh (faqat o'ziniki) ---------- */

/** 'paid' | 'partial' | 'unpaid' */
typedef MonthStatus = String;

class LedgerPayment {
  final String date;
  final double amount;
  final String? note;
  final String? comment;
  final String? month;
  final String? method;

  LedgerPayment({
    required this.date,
    required this.amount,
    this.note,
    this.comment,
    this.month,
    this.method,
  });

  factory LedgerPayment.fromJson(Map<String, dynamic> j) => LedgerPayment(
        date: _s(j['date']),
        amount: _d(j['amount']),
        note: _sn(j['note']),
        comment: _sn(j['comment']),
        month: _sn(j['month']),
        method: _sn(j['method']),
      );
}

/** Bitta oyda bitta guruhning jurnal holati — maosh ushlanmasining sababi */
class SalaryLessonStat {
  final String groupId;
  final String groupName;
  final int planned;
  final int conducted;
  final int missed;
  final double deduction;
  final List<String> missedDates;

  SalaryLessonStat({
    required this.groupId,
    required this.groupName,
    required this.planned,
    required this.conducted,
    required this.missed,
    required this.deduction,
    required this.missedDates,
  });

  factory SalaryLessonStat.fromJson(Map<String, dynamic> j) => SalaryLessonStat(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        planned: _i(j['planned']),
        conducted: _i(j['conducted']),
        missed: _i(j['missed']),
        deduction: _d(j['deduction']),
        missedDates: _strList(j['missedDates']),
      );
}

/** Oy bo'yicha maosh holati */
class MonthSalary {
  final String month;
  final double expected;
  final double paid;
  final double remaining;
  final MonthStatus status;
  final double? baseExpected;
  final double? deduction;
  final int? plannedLessons;
  final int? conductedLessons;
  final int? missedLessons;
  final List<SalaryLessonStat>? lessons;

  MonthSalary({
    required this.month,
    required this.expected,
    required this.paid,
    required this.remaining,
    required this.status,
    this.baseExpected,
    this.deduction,
    this.plannedLessons,
    this.conductedLessons,
    this.missedLessons,
    this.lessons,
  });

  factory MonthSalary.fromJson(Map<String, dynamic> j) => MonthSalary(
        month: _s(j['month']),
        expected: _d(j['expected']),
        paid: _d(j['paid']),
        remaining: _d(j['remaining']),
        status: _s(j['status']),
        baseExpected: _dn(j['baseExpected']),
        deduction: _dn(j['deduction']),
        plannedLessons: _in(j['plannedLessons']),
        conductedLessons: _in(j['conductedLessons']),
        missedLessons: _in(j['missedLessons']),
        lessons: j['lessons'] == null ? null : _list(j['lessons'], SalaryLessonStat.fromJson),
      );
}

/** Maosh hisobida bitta guruhning ulushi (davr bo'yicha) */
class GroupSalaryLine {
  final String groupId;
  final String groupName;
  final String courseName;
  final double monthlyFee;
  /** 'percent' | 'fixed' */
  final String mode;
  final double percent;
  final double fixed;
  final double periodCollected;
  final double periodExpected;

  GroupSalaryLine({
    required this.groupId,
    required this.groupName,
    required this.courseName,
    required this.monthlyFee,
    required this.mode,
    required this.percent,
    required this.fixed,
    required this.periodCollected,
    required this.periodExpected,
  });

  factory GroupSalaryLine.fromJson(Map<String, dynamic> j) => GroupSalaryLine(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        courseName: _s(j['courseName']),
        monthlyFee: _d(j['monthlyFee']),
        mode: _s(j['mode']),
        percent: _d(j['percent']),
        fixed: _d(j['fixed']),
        periodCollected: _d(j['periodCollected']),
        periodExpected: _d(j['periodExpected']),
      );
}

/** O'qituvchi maoshi bo'yicha batafsil hisob (davr bo'yicha) */
class SalaryLedger {
  final String teacherId;
  final String fullName;
  final double salary;
  final double totalExpected;
  final double totalPaid;
  final double remaining;
  final List<MonthSalary> months;
  final List<LedgerPayment> payments;
  final String? salaryMode;
  final double? salaryPercent;
  final List<GroupSalaryLine>? groups;
  final double? totalDeduction;
  final bool? journalLinked;

  SalaryLedger({
    required this.teacherId,
    required this.fullName,
    required this.salary,
    required this.totalExpected,
    required this.totalPaid,
    required this.remaining,
    required this.months,
    required this.payments,
    this.salaryMode,
    this.salaryPercent,
    this.groups,
    this.totalDeduction,
    this.journalLinked,
  });

  factory SalaryLedger.fromJson(Map<String, dynamic> j) => SalaryLedger(
        teacherId: _s(j['teacherId']),
        fullName: _s(j['fullName']),
        salary: _d(j['salary']),
        totalExpected: _d(j['totalExpected']),
        totalPaid: _d(j['totalPaid']),
        remaining: _d(j['remaining']),
        months: _list(j['months'], MonthSalary.fromJson),
        payments: _list(j['payments'], LedgerPayment.fromJson),
        salaryMode: _sn(j['salaryMode']),
        salaryPercent: _dn(j['salaryPercent']),
        groups: j['groups'] == null ? null : _list(j['groups'], GroupSalaryLine.fromJson),
        totalDeduction: _dn(j['totalDeduction']),
        journalLinked: _bn(j['journalLinked']),
      );
}

/* ---------- Guruh OYLIK jurnali (o'qituvchi guruh sahifasi) ---------- */

/** Dars o'zlashtirish darajasi: 0=NonReactive,1=Reactive,2=Active,3=ProActive */
typedef MasteryLevel = int;

class JournalColumn {
  final String date;
  final int period;

  JournalColumn({required this.date, required this.period});

  factory JournalColumn.fromJson(Map<String, dynamic> j) =>
      JournalColumn(date: _s(j['date']), period: _i(j['period']));
}

class JournalEntry {
  final String studentId;
  final String date;
  final int period;
  final int? grade;
  final String? reasonId;
  /** 0=belgilanmagan, 1=qildi, 2=qilmadi, 3=chala qildi */
  final int? homework;
  final int? behavior;
  final MasteryLevel? mastery;
  /** ANIQ "keldi (bor)" belgisi — orqaga sanalgan a'zolikda ham katak yashil ✓ bo'ladi */
  final bool present;

  JournalEntry({
    required this.studentId,
    required this.date,
    required this.period,
    this.grade,
    this.reasonId,
    this.homework,
    this.behavior,
    this.mastery,
    this.present = false,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        studentId: _s(j['studentId']),
        date: _s(j['date']),
        period: _i(j['period']),
        grade: _in(j['grade']),
        reasonId: _sn(j['reasonId']),
        homework: _in(j['homework']),
        behavior: _in(j['behavior']),
        mastery: _in(j['mastery']),
        present: _b(j['present']),
      );
}

class JournalTopic {
  final String date;
  final int period;
  final String topic;
  final String? homework;
  final bool conducted;

  JournalTopic({
    required this.date,
    required this.period,
    required this.topic,
    this.homework,
    required this.conducted,
  });

  factory JournalTopic.fromJson(Map<String, dynamic> j) => JournalTopic(
        date: _s(j['date']),
        period: _i(j['period']),
        topic: _s(j['topic']),
        homework: _sn(j['homework']),
        conducted: _b(j['conducted']),
      );
}

class GroupJournalInfo {
  final String id;
  final String name;
  final String courseId;
  final String courseName;
  final String teacherName;
  final List<int> days;
  final String startTime;
  final String endTime;
  final String room;
  final String startDate;
  final double monthlyFee;

  GroupJournalInfo({
    required this.id,
    required this.name,
    required this.courseId,
    required this.courseName,
    required this.teacherName,
    required this.days,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.startDate,
    required this.monthlyFee,
  });

  factory GroupJournalInfo.fromJson(Map<String, dynamic> j) => GroupJournalInfo(
        id: _s(j['id']),
        name: _s(j['name']),
        courseId: _s(j['courseId']),
        courseName: _s(j['courseName']),
        teacherName: _s(j['teacherName']),
        days: _intList(j['days']),
        startTime: _s(j['startTime']),
        endTime: _s(j['endTime']),
        room: _s(j['room']),
        startDate: _s(j['startDate']),
        monthlyFee: _d(j['monthlyFee']),
      );
}

class GroupJournalStudent {
  final String studentId;
  final String fullName;
  final String status;
  final String activatedAt;
  /** O'quvchi balansi (manfiy = qarz) */
  final double balance;
  /** O'quvchi guruhda boshlangan sana ("yyyy-MM-dd") */
  final String memberStart;
  /** Shu sanadan OLDINGI o'tilgan darslarda yozuv bo'lmasa avtomatik "keldi" ko'rsatilmaydi
      (bo'sh = cheklovsiz). Web bilan bir xil: `presentDefaultFrom`. */
  final String presentDefaultFrom;
  /** Muzlatilgan sana (bo'sh = muzlatilmagan) */
  final String frozenAt;

  /** SHU GURUH bo'yicha to'liq yopilmagan (qarzdor) oylar soni. 2 va undan ko'p bo'lsa
      ism binafsha-pushti rangda ko'rsatiladi (web bilan bir xil, `HEAVY_DEBT_MONTHS`). */
  final int debtMonths;

  GroupJournalStudent({
    required this.studentId,
    required this.fullName,
    required this.status,
    required this.activatedAt,
    required this.balance,
    required this.memberStart,
    this.presentDefaultFrom = '',
    this.frozenAt = '',
    this.debtMonths = 0,
  });

  factory GroupJournalStudent.fromJson(Map<String, dynamic> j) => GroupJournalStudent(
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        status: _s(j['status']),
        activatedAt: _s(j['activatedAt']),
        balance: _d(j['balance']),
        memberStart: _s(j['memberStart']),
        presentDefaultFrom: _s(j['presentDefaultFrom']),
        frozenAt: _s(j['frozenAt']),
        debtMonths: _i(j['debtMonths']),
      );
}

/** Bitta darsning bir martalik boshqa kunga ko'chirilishi */
class LessonReschedule {
  final String id;
  final String fromDate;
  final String toDate;
  final String? time;

  LessonReschedule({
    required this.id,
    required this.fromDate,
    required this.toDate,
    this.time,
  });

  factory LessonReschedule.fromJson(Map<String, dynamic> j) => LessonReschedule(
        id: _s(j['id']),
        fromDate: _s(j['fromDate']),
        toDate: _s(j['toDate']),
        time: _sn(j['time']),
      );
}

class GroupJournal {
  final GroupJournalInfo group;
  final List<String> months;
  final String month;
  final List<JournalColumn> columns;
  final List<GroupJournalStudent> students;
  final List<JournalEntry> entries;
  /** "O'tildi" deb belgilangan dars sanalari */
  final List<String> conductedDates;
  /** Shu oyga tegishli dars ko'chirishlari */
  final List<LessonReschedule> reschedules;

  GroupJournal({
    required this.group,
    required this.months,
    required this.month,
    required this.columns,
    required this.students,
    required this.entries,
    required this.conductedDates,
    required this.reschedules,
  });

  factory GroupJournal.fromJson(Map<String, dynamic> j) => GroupJournal(
        // `group` kelmasa ham sahifa ochilishi kerak — `GroupJournalInfo` ning
        // hamma maydoni `_s`/`_i`/`_d` orqali o'tadi, bo'sh map yetarli.
        group: GroupJournalInfo.fromJson(_map(j['group'])),
        months: _strList(j['months']),
        month: _s(j['month']),
        columns: _list(j['columns'], JournalColumn.fromJson),
        students: _list(j['students'], GroupJournalStudent.fromJson),
        entries: _list(j['entries'], JournalEntry.fromJson),
        conductedDates: _strList(j['conductedDates']),
        reschedules: _list(j['reschedules'], LessonReschedule.fromJson),
      );
}

/* ---------- Baholash mezonlari (o'z guruhi) ---------- */

class GradingBoardCriterion {
  final String id;
  final String name;
  final int order;

  GradingBoardCriterion({required this.id, required this.name, required this.order});

  factory GradingBoardCriterion.fromJson(Map<String, dynamic> j) => GradingBoardCriterion(
        id: _s(j['id']),
        name: _s(j['name']),
        order: _i(j['order']),
      );
}

class GradingBoardStudent {
  final String studentId;
  final String fullName;
  /** "criterionId|date" — "bajardi" belgilangan kataklar */
  final List<String> doneKeys;

  GradingBoardStudent({
    required this.studentId,
    required this.fullName,
    required this.doneKeys,
  });

  factory GradingBoardStudent.fromJson(Map<String, dynamic> j) => GradingBoardStudent(
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        doneKeys: _strList(j['doneKeys']),
      );
}

class GradingBoard {
  final String groupId;
  final String groupName;
  final List<String> months;
  final String month;
  final List<String> dates;
  final List<GradingBoardCriterion> criteria;
  final List<GradingBoardStudent> students;

  GradingBoard({
    required this.groupId,
    required this.groupName,
    required this.months,
    required this.month,
    required this.dates,
    required this.criteria,
    required this.students,
  });

  factory GradingBoard.fromJson(Map<String, dynamic> j) => GradingBoard(
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        months: _strList(j['months']),
        month: _s(j['month']),
        dates: _strList(j['dates']),
        criteria: _list(j['criteria'], GradingBoardCriterion.fromJson),
        students: _list(j['students'], GradingBoardStudent.fromJson),
      );
}

class SetGrade {
  final String groupId;
  final String studentId;
  final String criterionId;
  final String date;
  final bool done;

  SetGrade({
    required this.groupId,
    required this.studentId,
    required this.criterionId,
    required this.date,
    required this.done,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'studentId': studentId,
        'criterionId': criterionId,
        'date': date,
        'done': done,
      };
}

class BulkGrade {
  final String groupId;
  final String criterionId;
  final String date;
  final bool done;

  BulkGrade({
    required this.groupId,
    required this.criterionId,
    required this.date,
    required this.done,
  });

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'criterionId': criterionId,
        'date': date,
        'done': done,
      };
}

/* ---------- Guruh o'quv dasturi (curriculum) ---------- */

class GroupCurriculumItem {
  final String id;
  final String text;
  final String note;
  final int order;
  final bool covered;
  final String coveredDate;

  GroupCurriculumItem({
    required this.id,
    required this.text,
    required this.note,
    required this.order,
    required this.covered,
    required this.coveredDate,
  });

  factory GroupCurriculumItem.fromJson(Map<String, dynamic> j) => GroupCurriculumItem(
        id: _s(j['id']),
        text: _s(j['text']),
        note: _s(j['note']),
        order: _i(j['order']),
        covered: _b(j['covered']),
        coveredDate: _s(j['coveredDate']),
      );
}

class GroupCurriculumTopic {
  final String id;
  final String title;
  final String note;
  final int order;
  final List<GroupCurriculumItem> items;

  GroupCurriculumTopic({
    required this.id,
    required this.title,
    required this.note,
    required this.order,
    required this.items,
  });

  factory GroupCurriculumTopic.fromJson(Map<String, dynamic> j) => GroupCurriculumTopic(
        id: _s(j['id']),
        title: _s(j['title']),
        note: _s(j['note']),
        order: _i(j['order']),
        items: _list(j['items'], GroupCurriculumItem.fromJson),
      );
}

class GroupCurriculumLevel {
  final String id;
  final String name;
  final String note;
  final int order;
  final List<GroupCurriculumTopic> topics;

  GroupCurriculumLevel({
    required this.id,
    required this.name,
    required this.note,
    required this.order,
    required this.topics,
  });

  factory GroupCurriculumLevel.fromJson(Map<String, dynamic> j) => GroupCurriculumLevel(
        id: _s(j['id']),
        name: _s(j['name']),
        note: _s(j['note']),
        order: _i(j['order']),
        topics: _list(j['topics'], GroupCurriculumTopic.fromJson),
      );
}

class GroupCurriculum {
  final String groupId;
  final String courseId;
  final String courseName;
  final int totalItems;
  final int coveredCount;
  final int revisionLessons;
  final int totalLessons;
  final int remainingItems;
  final int estLessonsLeft;
  final int lessonsPerWeek;
  /** ISO sana yoki null — taxminiy tugash sanasi */
  final String? estFinishDate;
  final List<GroupCurriculumLevel> levels;

  GroupCurriculum({
    required this.groupId,
    required this.courseId,
    required this.courseName,
    required this.totalItems,
    required this.coveredCount,
    required this.revisionLessons,
    required this.totalLessons,
    required this.remainingItems,
    required this.estLessonsLeft,
    required this.lessonsPerWeek,
    this.estFinishDate,
    required this.levels,
  });

  factory GroupCurriculum.fromJson(Map<String, dynamic> j) => GroupCurriculum(
        groupId: _s(j['groupId']),
        courseId: _s(j['courseId']),
        courseName: _s(j['courseName']),
        totalItems: _i(j['totalItems']),
        coveredCount: _i(j['coveredCount']),
        revisionLessons: _i(j['revisionLessons']),
        totalLessons: _i(j['totalLessons']),
        remainingItems: _i(j['remainingItems']),
        estLessonsLeft: _i(j['estLessonsLeft']),
        lessonsPerWeek: _i(j['lessonsPerWeek']),
        estFinishDate: _sn(j['estFinishDate']),
        // Backend maydon nomi — `modules` (web `GroupCurriculum.modules`). Avval faqat
        // `levels` o'qilardi va daraxt HAR DOIM bo'sh kelardi; `levels` zaxira sifatida qoldi.
        // `??` yetarli emas edi: `modules: []` null emas, shuning uchun zaxira ishlamasdi.
        levels: _list(_orFallback(j['modules'], j['levels']), GroupCurriculumLevel.fromJson),
      );
}

/* ---------- O'qituvchi profili va bildirishnomalar ---------- */

class TeacherProfile {
  final String id;
  final String fullName;
  final String email;
  final String homeroomClass;
  final List<Subject> subjects;
  /** Support o'qituvchimi (bo'sh vaqt/bron bo'limi ko'rinadimi) */
  final bool? isSupport;

  TeacherProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.homeroomClass,
    required this.subjects,
    this.isSupport,
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> j) => TeacherProfile(
        id: _s(j['id']),
        fullName: _s(j['fullName']),
        email: _s(j['email']),
        homeroomClass: _s(j['homeroomClass']),
        subjects: _list(j['subjects'], Subject.fromJson),
        isSupport: _bn(j['isSupport']),
      );
}

/** Markaz nomi + Telegram kanali (/teacher/school javobi) */
class TeacherSchoolInfo {
  final String name;
  final String telegramChannel;

  TeacherSchoolInfo({required this.name, required this.telegramChannel});

  factory TeacherSchoolInfo.fromJson(Map<String, dynamic> j) => TeacherSchoolInfo(
        name: _s(j['name']),
        telegramChannel: _s(j['telegramChannel']),
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String createdAt;
  final bool read;
  final bool confirmed;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.confirmed,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: _s(j['id']),
        title: _s(j['title']),
        body: _s(j['body']),
        type: _s(j['type']),
        createdAt: _s(j['createdAt']),
        read: _b(j['read']),
        confirmed: _b(j['confirmed']),
      );
}

class NotificationsResponse {
  final int unread;
  final List<AppNotification> items;

  NotificationsResponse({required this.unread, required this.items});

  factory NotificationsResponse.fromJson(Map<String, dynamic> j) => NotificationsResponse(
        unread: _i(j['unread']),
        items: _list(j['items'], AppNotification.fromJson),
      );
}

/* ---------- O'quvchilar reytingi (o'z guruhlari, ball bo'yicha) ---------- */

class TeacherRatingRow {
  /** O'rin (1 = eng yuqori ball) */
  final int rank;
  final String studentId;
  final String fullName;
  /** Shu o'qituvchining qaysi guruhlarida o'qiydi (vergul bilan) */
  final String groups;
  final int journalTotal;
  final int criteriaDone;
  final int ball;
  final double average;
  /** Davomat % (o'tilgan dars yo'q bo'lsa null) */
  final double? attendance;

  TeacherRatingRow({
    required this.rank,
    required this.studentId,
    required this.fullName,
    required this.groups,
    required this.journalTotal,
    required this.criteriaDone,
    required this.ball,
    required this.average,
    this.attendance,
  });

  factory TeacherRatingRow.fromJson(Map<String, dynamic> j) => TeacherRatingRow(
        rank: _i(j['rank']),
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        groups: _s(j['groups']),
        journalTotal: _i(j['journalTotal']),
        criteriaDone: _i(j['criteriaDone']),
        ball: _i(j['ball']),
        average: _d(j['average']),
        attendance: _dn(j['attendance']),
      );
}

/** O'qituvchi guruhlaridagi o'quvchilar reytingi */
class TeacherRating {
  final String teacherId;
  final String fullName;
  final int groupsCount;
  final int studentsCount;
  final double averageBall;
  final List<TeacherRatingRow> rows;

  TeacherRating({
    required this.teacherId,
    required this.fullName,
    required this.groupsCount,
    required this.studentsCount,
    required this.averageBall,
    required this.rows,
  });

  factory TeacherRating.fromJson(Map<String, dynamic> j) => TeacherRating(
        teacherId: _s(j['teacherId']),
        fullName: _s(j['fullName']),
        groupsCount: _i(j['groupsCount']),
        studentsCount: _i(j['studentsCount']),
        averageBall: _d(j['averageBall']),
        rows: _list(j['rows'], TeacherRatingRow.fromJson),
      );
}

/* ---------- Test natijalari (o'z guruhlari) ---------- */

/// Onlayn test sozlamalari — web `OnlineTest` bilan bir xil shakl.
/// `mode`="offline" bo'lsa qolgan maydonlar e'tiborga olinmaydi (ballni o'qituvchi qo'lda kiritadi).
/// `mode`="online" — o'quvchi Telegram botdan ishlaydi, ball avtomatik yoziladi (har savol 1 ball).
class OnlineTest {
  /// "offline" | "online"
  final String mode;
  /// Savollar fayli ("/uploads/xxx.pdf") — botga shu yuboriladi
  final String pdfUrl;
  final String pdfName;
  /// Savollar soni (onlayn testda maxScore shunga teng)
  final int questionCount;
  /// Variantlar soni: 4 → A–D, 5 → A–E
  final int optionCount;
  /// To'g'ri javoblar ("ABCDA...", uzunligi = questionCount)
  final String answerKey;
  /// Javob qabul qilish oynasi (ISO "yyyy-MM-ddTHH:mm")
  final String startAt;
  final String endAt;

  const OnlineTest({
    this.mode = 'offline',
    this.pdfUrl = '',
    this.pdfName = '',
    this.questionCount = 0,
    this.optionCount = 4,
    this.answerKey = '',
    this.startAt = '',
    this.endAt = '',
  });

  bool get isOnline => mode == 'online';

  /// `mode` registr/probelga bog'liq bo'lmasligi kerak: backend "ONLINE" yuborsa
  /// ham test onlayn bo'lib qolishi shart. Bo'sh qiymat → "offline".
  static String _mode(dynamic v) {
    final s = _s(v).trim().toLowerCase();
    return s.isEmpty ? 'offline' : s;
  }

  /// 0/berilmagan → 4 (A–D standarti), qolgani 2..6 ga qisiladi:
  /// `group_tests_panel.dart` dagi variantlar dropdowni faqat shu oraliqni biladi.
  static int _options(dynamic v) {
    final n = _i(v);
    return n == 0 ? 4 : n.clamp(2, 6);
  }

  factory OnlineTest.fromJson(Map<String, dynamic> j) => OnlineTest(
        mode: _mode(j['mode']),
        pdfUrl: _s(j['pdfUrl']),
        pdfName: _s(j['pdfName']),
        questionCount: _i(j['questionCount']),
        optionCount: _options(j['optionCount']),
        // `answerKey` uzunligi ATAYLAB `questionCount` ga moslashtirilmaydi —
        // tahrirlash oynasi uni o'zi to'g'rilaydi va barcha o'quvchi joylari
        // `answerKey.length` bo'yicha aylanadi (chegaradan chiqish yo'q).
        answerKey: _s(j['answerKey']),
        startAt: _s(j['startAt']),
        endAt: _s(j['endAt']),
      );

  /// `null` bo'lgan/berilmagan/buzuq `online` maydoni — oflayn test.
  /// (String bo'lmagan kalitli Map ham butun testlar ekranini yiqitmasligi kerak.)
  static OnlineTest parse(Object? v) =>
      v is Map ? OnlineTest.fromJson(_map(v)) : const OnlineTest();

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'pdfUrl': pdfUrl,
        'pdfName': pdfName,
        'questionCount': questionCount,
        'optionCount': optionCount,
        'answerKey': answerKey,
        'startAt': startAt,
        'endAt': endAt,
      };
}

/// Bitta test qatori (guruh testlar ro'yxatida). Web: `GroupTest`.
class GroupTest {
  final String id;
  final String groupId;
  final String name;
  final String date;
  final double maxScore;
  final String createdAt;
  final String createdBy;
  final int studentCount;
  final int scoredCount;
  final double? avgScore;
  /// Onlayn test sozlamalari (oflaynda ham to'ldiriladi — mode="offline").
  final OnlineTest online;
  /// Botdan javob yuborgan o'quvchilar soni (onlayn test).
  final int submittedCount;

  GroupTest({
    required this.id,
    required this.groupId,
    required this.name,
    required this.date,
    required this.maxScore,
    required this.createdAt,
    required this.createdBy,
    required this.studentCount,
    required this.scoredCount,
    required this.avgScore,
    this.online = const OnlineTest(),
    this.submittedCount = 0,
  });

  factory GroupTest.fromJson(Map<String, dynamic> j) => GroupTest(
        id: _s(j['id']),
        groupId: _s(j['groupId']),
        name: _s(j['name']),
        date: _s(j['date']),
        maxScore: _d(j['maxScore']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        studentCount: _i(j['studentCount']),
        scoredCount: _i(j['scoredCount']),
        avgScore: _dn(j['avgScore']),
        online: OnlineTest.parse(j['online']),
        submittedCount: _i(j['submittedCount']),
      );
}

/// Test natijasi qatori — bitta o'quvchi bali (rank=0 → ball kiritilmagan).
class TestScoreRow {
  final String studentId;
  final String fullName;
  final double? score;
  final int rank;
  /// Onlayn: botdan yuborilgan javoblar ("ABDCA...")
  final String answers;
  /// Onlayn: yuborilgan vaqt (ISO)
  final String submittedAt;
  /// "bot" — o'quvchi botdan yubordi; "" — qo'lda kiritilgan
  final String source;

  TestScoreRow({
    required this.studentId,
    required this.fullName,
    required this.score,
    required this.rank,
    this.answers = '',
    this.submittedAt = '',
    this.source = '',
  });

  bool get fromBot => source == 'bot';

  factory TestScoreRow.fromJson(Map<String, dynamic> j) => TestScoreRow(
        studentId: _s(j['studentId']),
        fullName: _s(j['fullName']),
        score: _dn(j['score']),
        rank: _i(j['rank']),
        answers: _s(j['answers']),
        submittedAt: _s(j['submittedAt']),
        source: _s(j['source']),
      );
}

/// Test tafsiloti — test + o'quvchilar ballari (ball desc bo'yicha saralangan). Web: `TestResultDetail`.
class TestResultDetail {
  final String id;
  final String groupId;
  final String groupName;
  final String name;
  final String date;
  final double maxScore;
  final String createdAt;
  final String createdBy;
  final List<TestScoreRow> rows;
  /// Onlayn test sozlamalari (oflaynda mode="offline").
  final OnlineTest online;

  TestResultDetail({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.name,
    required this.date,
    required this.maxScore,
    required this.createdAt,
    required this.createdBy,
    required this.rows,
    this.online = const OnlineTest(),
  });

  /// Botdan javob yuborgan o'quvchilar soni.
  int get submittedCount => rows.where((r) => r.fromBot).length;

  factory TestResultDetail.fromJson(Map<String, dynamic> j) => TestResultDetail(
        id: _s(j['id']),
        groupId: _s(j['groupId']),
        groupName: _s(j['groupName']),
        name: _s(j['name']),
        date: _s(j['date']),
        maxScore: _d(j['maxScore']),
        createdAt: _s(j['createdAt']),
        createdBy: _s(j['createdBy']),
        rows: _list(j['rows'], TestScoreRow.fromJson),
        online: OnlineTest.parse(j['online']),
      );
}

/* ---------- Shartnoma (elektron nusxa) ---------- */

/// Tuzilgan shartnoma hujjati — backend `ContractDocDto`.
/// Ilovada faqat o'qish uchun: ro'yxat + PDF ochish.
class ContractDoc {
  final String id;
  final int number;

  /// "Shartnoma № 12" ko'rinishidagi tayyor sarlavha.
  final String title;

  /// "parent" | "staff" — o'qituvchi ilovasida doim "staff".
  final String target;
  final String recipientKey;
  final String recipientName;

  /// Andoza nomi (tarixiy nusxa — andoza o'chirilsa ham qoladi).
  final String templateName;

  /// Tuzilgan sana (ISO).
  final String date;

  /// Superadmin yuklagan PDF ("/uploads/...") — ilovada shu ochiladi.
  /// Server faqat PDF'i bor yozuvlarni qaytargani uchun doim to'ldirilgan.
  final String pdfUrl;

  /// Tizim hosil qilgan Word nusxa (admin panelida ishlatiladi).
  final String docxUrl;
  final bool delivered;
  final String status;

  /// Oluvchiga ko'rsatish belgisi — serverning o'zi filtrlab beradi.
  final bool visible;

  ContractDoc({
    required this.id,
    required this.number,
    required this.title,
    required this.target,
    required this.recipientKey,
    required this.recipientName,
    required this.templateName,
    required this.date,
    required this.pdfUrl,
    required this.docxUrl,
    required this.delivered,
    required this.status,
    required this.visible,
  });

  factory ContractDoc.fromJson(Map<String, dynamic> j) => ContractDoc(
        id: _s(j['id']),
        number: _i(j['number']),
        title: _s(j['title']),
        target: _s(j['target']),
        recipientKey: _s(j['recipientKey']),
        recipientName: _s(j['recipientName']),
        templateName: _s(j['templateName']),
        date: _s(j['date']),
        pdfUrl: _s(j['pdfUrl']),
        docxUrl: _s(j['docxUrl']),
        delivered: _b(j['delivered']),
        status: _s(j['status']),
        visible: _b(j['visible']),
      );
}
