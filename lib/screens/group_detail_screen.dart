import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import 'group_contact_tab.dart';
import 'group_grading_section.dart';
import 'group_rating_tab.dart';
import 'group_tests_panel.dart';

const _weekdayShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

/// Guruh sahifasi — web `TeacherGroupDetailPage.tsx` bilan BIR XIL to'liq to'plam:
/// guruh ma'lumoti + 6 tab (Jurnal, Davomat, Baholash, Reyting, Imtihonlar, Aloqa).
///
/// Bu sahifaga Dashboard'dagi guruh kartasidan kiriladi (pastki navigatsiyada alohida
/// «Jurnal» tabi YO'Q).
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  const GroupDetailScreen({super.key, required this.groupId, this.groupName = ''});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

/// Guruh sahifasidagi ko'rinishlar (web `groupView`).
enum _GroupView { jurnal, davomat, baholash, reyting, imtihonlar, aloqa }

/// Jurnal qatori — o'quvchi + hisoblangan yig'indilar (saralash uchun).
class _ScoredStudent {
  final GroupJournalStudent student;
  final int journalTotal;
  final int gradingTotal;
  final int originalIndex;
  const _ScoredStudent(this.student, this.journalTotal, this.gradingTotal, this.originalIndex);

  /// Web `combinedTotal` — jurnal baholari + bajarilgan baholash mezonlari.
  int get combinedTotal => journalTotal + gradingTotal;
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupJournal? _journal;
  /// Joriy oy baholash jadvali — «Jami» ustuni va saralash uchun (web bilan bir xil
  /// formula: jurnal bahosi + bajarilgan mezonlar). Yuklanmasa null (jurnal ishlaydi).
  GradingBoard? _grading;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<AbsenceReason> _reasons = [];
  _GroupView _view = _GroupView.jurnal;

  /// Davomat sabablari (`/teacher/meta`) yuklanmadi — kelmagan o'quvchi kataklari
  /// sabab qisqartmasi o'rniga «?» bilan chiziladi va tepada ogohlantirish turadi.
  bool _reasonsFailed = false;

  /// Baholash jadvali yuklanmadi — «Jami» ustuni TO'LIQ EMAS (jimgina noto'g'ri
  /// reyting ko'rsatmaslik uchun raqam o'rniga «—» chiziladi).
  bool _gradingFailed = false;

  /// So'rov tokeni — oy chiplarini tez bosganda ESKI javob YANGI oy ustiga
  /// yozilmasligi uchun (namuna: `group_rating_tab.dart:124`). Jurnal ham,
  /// baholash ham AYNI tokenni tekshiradi — aks holda May'ning baholashi
  /// Iyun jurnaliga ulanib qolardi.
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _loadReasons();
    _load();
  }

  /// Xato matni — `ApiException` bo'lsa o'zbekcha `message`, aks holda umumiy matn.
  String _msg(Object e, String fallback) => e is ApiException ? e.message : fallback;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadReasons() async {
    try {
      final meta = await TeacherApi.meta();
      if (!mounted) return;
      setState(() {
        _reasons = meta?.absenceReasons ?? [];
        _reasonsFailed = false;
      });
    } catch (_) {
      // Sabablar yuklanmasa jurnal ishlashda davom etadi, LEKIN kelmaganlik
      // yashil ✓ ga aylanib ketmasligi uchun buni yashirmaymiz.
      if (!mounted) return;
      setState(() => _reasonsFailed = true);
    }
  }

  Future<void> _load([String? month]) async {
    // C2: `_load` saqlashdan KEYIN (`await`dan so'ng) ham chaqiriladi — o'sha
    // paytda ekran yopilgan bo'lishi mumkin.
    if (!mounted) return;
    final token = ++_reqId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await TeacherApi.groupJournal(widget.groupId, month: month);
      if (!mounted || token != _reqId) return;
      setState(() {
        _journal = j;
        _loading = false;
      });
      _loadGrading(j.month, token);
    } catch (e) {
      if (!mounted || token != _reqId) return;
      final msg = _msg(e, "Jurnalni yuklab bo'lmadi");
      setState(() {
        _loading = false;
        // U2: allaqachon ko'rinib turgan jurnalni bitta muvaffaqiyatsiz
        // yangilash uchun YO'QOTMAYMIZ — faqat xabar beramiz
        // (namuna: `group_grading_section.dart:96-99`).
        if (_journal == null) _error = msg;
      });
      if (_journal != null) _toast(msg);
    }
  }

  /// Baholash jadvali — «Jami» ustuni uchun (xatosi jurnalni bloklamaydi, lekin
  /// JIMGINA ham qolmaydi: bayroq + ogohlantirish + «—»).
  Future<void> _loadGrading(String month, [int? token]) async {
    try {
      final g = await TeacherApi.gradingBoard(widget.groupId, month: month);
      if (!mounted || (token != null && token != _reqId)) return;
      setState(() {
        _grading = g;
        _gradingFailed = false;
      });
    } catch (e) {
      if (!mounted || (token != null && token != _reqId)) return;
      setState(() {
        _grading = null;
        _gradingFailed = true;
      });
      _toast(_msg(e, "Baholash jadvali yuklanmadi — «Jami» to'liq emas"));
    }
  }

  String get _todayIso {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// R3: sanalarni SOLISHTIRISHDAN oldin "yyyy-MM-dd" ga qisqartiramiz — server
  /// bir joyda `2026-03-05`, boshqa joyda `2026-03-05T00:00:00` qaytarsa ham
  /// taqqoslash buzilmasin (bo'lmasa a'zolik boshlangan kun «berk» bo'lib qolardi).
  static String _dayKey(String date) => date.length > 10 ? date.substring(0, 10) : date;

  JournalEntry? _entryFor(GroupJournal j, String studentId, String date) {
    final key = _dayKey(date);
    for (final e in j.entries) {
      if (e.studentId == studentId && _dayKey(e.date) == key) return e;
    }
    return null;
  }

  bool _isConducted(GroupJournal j, String date) {
    final key = _dayKey(date);
    for (final d in j.conductedDates) {
      if (_dayKey(d) == key) return true;
    }
    return false;
  }

  /// Faol (muzlatilmagan) o'quvchilar, «Jami» bo'yicha kamayish tartibida saralangan —
  /// web `sortedAndScoredStudents` bilan bir xil.
  List<_ScoredStudent> _scoredStudents(GroupJournal j) {
    final base = j.students.where((s) => s.status != 'frozen').toList();
    final doneByStudent = <String, int>{
      for (final gs in _grading?.students ?? const <GradingBoardStudent>[])
        gs.studentId: gs.doneKeys.toSet().length,
    };
    final rows = <_ScoredStudent>[];
    for (var i = 0; i < base.length; i++) {
      final s = base[i];
      var journalTotal = 0;
      for (final col in j.columns) {
        // P1-5: a'zolik (yoki guruh) boshlanishidan OLDINGI katak bo'sh va
        // BOSILMAYDIGAN qilib chiziladi — o'qituvchi u yerdagi bahoni o'chira
        // olmaydi, shuning uchun u «Jami»ga ham qo'shilmasligi kerak.
        if (_isBeforeStart(j, s, col.date)) continue;
        final e = _entryFor(j, s.studentId, col.date);
        if (e?.grade != null) journalTotal += e!.grade!;
      }
      rows.add(_ScoredStudent(s, journalTotal, doneByStudent[s.studentId] ?? 0, i));
    }
    rows.sort((a, b) {
      final byTotal = b.combinedTotal.compareTo(a.combinedTotal);
      return byTotal != 0 ? byTotal : a.originalIndex.compareTo(b.originalIndex);
    });
    return rows;
  }

  /// "Kech qoldi" sabablari davomat foiziga hisoblanmaydi (web bilan bir xil qoida).
  Set<String> get _lateReasonIds =>
      _reasons.where((r) => r.isLate).map((r) => r.id).toSet();

  /// Shu oyga ko'chirilgan darslar: yangi kun (toDate) → ko'chirish yozuvi.
  Map<String, LessonReschedule> _rescheduledByDate(GroupJournal j) => {
        for (final r in j.reschedules) _dayKey(r.toDate): r,
      };

  bool _isBeforeStart(GroupJournal j, GroupJournalStudent s, String date) {
    final d = _dayKey(date);
    final beforeMember =
        s.memberStart.isNotEmpty && d.compareTo(_dayKey(s.memberStart)) < 0;
    final beforeGroup =
        j.group.startDate.isNotEmpty && d.compareTo(_dayKey(j.group.startDate)) < 0;
    return beforeMember || beforeGroup;
  }

  /// Jurnal katagi (`_cell`) shu darsni o'quvchi uchun UMUMAN hisobga oladimi.
  ///
  /// P1-4: Davomat tabi ayni shu qoidadan foydalanishi shart — aks holda grid
  /// «·» chizadigan darslar Davomatda "keldi" bo'lib sanaladi va foiz ham,
  /// dars soni ham shishib ketadi.
  bool _countsForAttendance(GroupJournal j, GroupJournalStudent s, String date) {
    if (_isBeforeStart(j, s, date)) return false;
    final e = _entryFor(j, s.studentId, date);
    // Aniq belgi bor (baho / sabab / «keldi (bor)») — dars albatta hisobga olinadi.
    if (e != null && (e.grade != null || e.reasonId != null || e.present)) return true;
    // Belgisiz dars faqat `presentDefaultFrom` dan keyin avto-"keldi" bo'ladi.
    return s.presentDefaultFrom.isEmpty ||
        _dayKey(date).compareTo(_dayKey(s.presentDefaultFrom)) >= 0;
  }

  void _alert(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xatolik'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _openCell(GroupJournal journal, GroupJournalStudent s, String date) async {
    final entry = _entryFor(journal, s.studentId, date);
    final c = AppTheme.of(context);
    final result = await showModalBottomSheet<_CellSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _JournalCellSheet(
        studentName: s.fullName,
        dateLabel: fmtDate(date, weekday: true),
        entry: entry,
        reasons: _reasons,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    // DIQQAT: qayta yuklash (`_load`) SAQLASH try/catch'idan TASHQARIDA —
    // u o'z xatosini o'zi ko'rsatadi va, eng muhimi, uning `mounted` qorovuli
    // (C2) shu yerdagi `catch` tomonidan jimgina yutilmaydi.
    var saved = false;
    try {
      if (result.clear) {
        await TeacherApi.clearJournalEntry(journal.group.id, journal.group.courseId, s.studentId, date);
      } else {
        await TeacherApi.setJournalEntry(
          journal.group.id,
          journal.group.courseId,
          s.studentId,
          date,
          grade: result.grade,
          reasonId: result.reasonId,
          homework: result.homework,
          behavior: result.behavior,
          mastery: result.mastery,
          present: result.present,
        );
      }
      saved = true;
    } catch (e) {
      if (mounted) _alert(_msg(e, "Saqlab bo'lmadi — qayta urinib ko'ring"));
    }
    if (saved) await _load(journal.month);
    if (mounted) setState(() => _saving = false);
  }

  /// Sarlavhadagi sana bosilganda — hammaga birdan davomat + darsni ko'chirish.
  Future<void> _openBulk(String date) async {
    final journal = _journal;
    if (journal == null) return;
    // R2: shu SANADA hali guruhga qo'shilmagan o'quvchilarga yozmaymiz — ularning
    // kataklari gridda ataylab bo'sh va bosilmaydigan qilib chizilgan.
    final students = _scoredStudents(journal)
        .where((s) => !_isBeforeStart(journal, s.student, date))
        .toList();
    final c = AppTheme.of(context);
    final result = await showModalBottomSheet<_BulkResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _BulkAttendanceSheet(
        date: date,
        count: students.length,
        reasons: _reasons.where((r) => !r.isLate).toList(),
        defaultTime: journal.group.startTime,
        // Bu ustunning o'zi ko'chirilgan dars bo'lsa — asl kuniga qaytarish taklif qilinadi.
        reschedule: _rescheduledByDate(journal)[date],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    // `_openCell` bilan bir xil qoida (C2): qayta yuklash try/catch'dan tashqarida.
    var saved = false;
    try {
      switch (result.kind) {
        case _BulkKind.attendance:
          await TeacherApi.bulkAttendance(
            journal.group.id,
            journal.group.courseId,
            1,
            students.map((s) => s.student.studentId).toList(),
            date,
            result.absent,
            reasonId: result.reasonId,
          );
          break;
        case _BulkKind.reschedule:
          await TeacherApi.rescheduleLesson(
            journal.group.id,
            date,
            result.toDate!,
            time: result.time,
          );
          break;
        case _BulkKind.cancelReschedule:
          await TeacherApi.cancelReschedule(result.rescheduleId!);
          break;
      }
      saved = true;
    } catch (e) {
      if (mounted) _alert(_msg(e, "Saqlab bo'lmadi — qayta urinib ko'ring"));
    }
    if (saved) await _load(journal.month);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: widget.groupName.isEmpty ? (_journal?.group.name ?? 'Guruh') : widget.groupName,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: _body(context),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: const Center(child: Loader()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final journal = _journal;
    // U2: xato FAQAT hech nima yuklanmagan bo'lsa butun ekranni egallaydi;
    // yuklangan jurnal ustidan xato satri chizilmaydi (toast beriladi).
    if (_error != null && journal == null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: _error!));
    }
    if (_loading && journal == null) {
      return const Loader(label: 'Yuklanmoqda...');
    }
    if (journal == null) {
      return const EmptyState(text: 'Guruh topilmadi');
    }
    final students = _scoredStudents(journal);

    // Butun sahifa (info + tablar + tanlangan bo'lim + o'quv dasturi) birga scroll bo'ladi.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoCard(context, journal, students.length),
          const SizedBox(height: 10),
          _tabBar(context),
          const SizedBox(height: 10),
          switch (_view) {
            _GroupView.jurnal => _journalTab(context, journal, students),
            _GroupView.davomat => _attendanceTab(context, journal, students),
            _GroupView.baholash => GroupGradingSection(
                groupId: widget.groupId,
                initialMonth: journal.month,
              ),
            _GroupView.reyting => GroupRatingTab(
                groupId: widget.groupId,
                months: journal.months,
                defaultMonth: journal.month,
              ),
            _GroupView.imtihonlar => GroupTestsPanel(
                groupId: widget.groupId,
                title: 'Imtihonlar (testlar)',
              ),
            // «Aloqa» — o'quvchini "Bog'lanish kerak" navbatiga yuborish.
            // DIQQAT: jurnal ro'yxati TO'LIQ beriladi (muzlatilganlar bilan) —
            // ularni chiqarib tashlash qoidasi komponent ICHIDA, chunki u admin
            // jurnalida ham AYNI shunday bo'lishi kerak (web bilan bir xil).
            _GroupView.aloqa => GroupContactTab(
                students: journal.students,
                loadReasons: TeacherApi.contactReasons,
                onSend: (ids, reasonId, note) => TeacherApi.sendToContactQueue(
                  widget.groupId,
                  ids,
                  reasonId,
                  note,
                ),
              ),
          },
        ],
      ),
    );
  }

  Widget _tabBar(BuildContext context) {
    final c = AppTheme.of(context);
    const items = [
      (_GroupView.jurnal, 'Jurnal'),
      (_GroupView.davomat, 'Davomat'),
      (_GroupView.baholash, 'Baholash'),
      (_GroupView.reyting, 'Reyting'),
      (_GroupView.imtihonlar, 'Imtihonlar'),
      (_GroupView.aloqa, 'Aloqa'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (view, label) in items) ...[
              GestureDetector(
                onTap: () {
                  setState(() => _view = view);
                  // Jurnalga qaytilganda ma'lumot yangilanadi (web bilan bir xil).
                  if (view == _GroupView.jurnal) _load(_journal?.month);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _view == view ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _view == view ? c.shadow : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _view == view ? c.text : c.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context, GroupJournal journal, int studentsCount) {
    final c = AppTheme.of(context);
    final g = journal.group;
    final days = g.days.isEmpty
        ? '—'
        : g.days.map((d) => (d >= 0 && d < 7) ? _weekdayShort[d] : '$d').join(', ');
    final time = (g.startTime.isEmpty && g.endTime.isEmpty)
        ? '—'
        : '${g.startTime.isEmpty ? '—' : g.startTime}${g.endTime.isEmpty ? '' : ' – ${g.endTime}'}';
    final items = <(IconData, String, String)>[
      (Icons.menu_book_outlined, 'Kurs', g.courseName.isEmpty ? '—' : g.courseName),
      (Icons.person_outline, "O'qituvchi", g.teacherName.isEmpty ? '—' : g.teacherName),
      (Icons.calendar_today_outlined, 'Kunlar', days),
      (Icons.access_time, 'Vaqt', time),
      (Icons.place_outlined, 'Xona', g.room.isEmpty ? '—' : g.room),
      (Icons.groups_outlined, "O'quvchilar", '$studentsCount'),
    ];
    // Ikki ustun — card baland bo'lib ketmasligi uchun.
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _infoRow(c, items[i].$1, items[i].$2, items[i].$3)),
                const SizedBox(width: 12),
                if (i + 1 < items.length)
                  Expanded(child: _infoRow(c, items[i + 1].$1, items[i + 1].$2, items[i + 1].$3))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(AppColors c, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 15, color: c.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.faint, letterSpacing: 0.3),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthChips(BuildContext context, GroupJournal journal) {
    final c = AppTheme.of(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: journal.months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = journal.months[i];
          final active = m == journal.month;
          return GestureDetector(
            onTap: () => _load(m),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? c.accent : c.surface3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                fmtMonth(m),
                style: TextStyle(
                  color: active ? Colors.white : c.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /* ---------------- Jurnal tabi ---------------- */

  Widget _journalTab(BuildContext context, GroupJournal journal, List<_ScoredStudent> students) {
    final reasonById = <String, AbsenceReason>{for (final r in _reasons) r.id: r};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (journal.months.isNotEmpty) ...[
          _monthChips(context, journal),
          const SizedBox(height: 10),
        ],
        ..._warnings(context),
        _gridArea(context, journal, students, reasonById),
      ],
    );
  }

  /// Ma'lumot TO'LIQ EMASligi haqidagi ko'rinadigan ogohlantirishlar
  /// (jimgina noto'g'ri jurnal/reyting ko'rsatmaslik uchun).
  List<Widget> _warnings(BuildContext context) {
    final out = <Widget>[];
    if (_reasonsFailed) {
      out
        ..add(_warnBanner(context,
            "Davomat sabablari yuklanmadi — kelmagan o'quvchi katagi «?» bilan chiziladi."))
        ..add(const SizedBox(height: 8));
    }
    if (_gradingFailed) {
      out
        ..add(_warnBanner(context,
            "Baholash jadvali yuklanmadi — «Jami» ustuni va tartib to'liq emas."))
        ..add(const SizedBox(height: 8));
    }
    return out;
  }

  Widget _warnBanner(BuildContext context, String text) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: c.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: c.text, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _gridArea(
    BuildContext context,
    GroupJournal journal,
    List<_ScoredStudent> students,
    Map<String, AbsenceReason> reasonById,
  ) {
    if (journal.group.courseId.isEmpty) {
      return const EmptyState(text: "Guruhga kurs biriktirilmagan — jurnal yuritib bo'lmaydi.");
    }
    if (students.isEmpty) {
      return const EmptyState(text: "Bu guruhda faol o'quvchi yo'q.");
    }
    if (journal.columns.isEmpty) {
      return EmptyState(text: "${fmtMonth(journal.month)} oyida bu guruh kunlariga dars to'g'ri kelmadi.");
    }

    const rowH = 48.0;
    const numW = 26.0;
    const nameW = 118.0;
    const cellW = 46.0;
    const totalW = 46.0;
    final c = AppTheme.of(context);
    final rescheduled = _rescheduledByDate(journal);

    // O'quvchi ismi to'liq (tag-ma-tag) chiqishi uchun har qatorning balandligini
    // o'lchaymiz va uni ham ism ustuni, ham katak qatoriga qo'llaymiz (moslashadi).
    //
    // DIQQAT: uslub ATAYLAB `DefaultTextStyle`dan MEROS OLMAYDI (`inherit: false`) va
    // `decoration: none` bilan beriladi — meros olinganda FISH ostida SARIQ chiziq
    // (Flutter'ning "Material'siz matn" ogohlantirish underline'i) ko'rinib qolardi.
    final nameStyle = TextStyle(
      inherit: false,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFamily: kTeacherFontFamily,
      fontFamilyFallback: kTeacherFontFallback,
      height: 1.25,
      decoration: TextDecoration.none,
      color: c.text,
    );
    final scaler = MediaQuery.textScalerOf(context);
    double nameHeight(String name) {
      final tp = TextPainter(
        text: TextSpan(text: name.isEmpty ? '—' : name, style: nameStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        // Haqiqiy joydan (118 − padding 20 − chegara 1.5 ≈ 96.5) TORROQ o'lchaymiz —
        // shunda o'lchangan balandlik haqiqiysidan kam bo'lmaydi va matn qatordan
        // "chiqib" ketmaydi (aks holda Flutter debug rejimida katak ostida SARIQ-qora
        // "overflow" chizig'ini chizadi — FISH tagidagi sariq chiziq shundan).
      )..layout(maxWidth: nameW - 28);
      return tp.height;
    }

    final heights = <String, double>{
      // padding(12) + chegara(~2) + zaxira — ism har doim to'liq sig'adi.
      for (final s in students) s.student.studentId: math.max(56.0, nameHeight(s.student.fullName) + 30),
    };

    return SCard(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapda yopishib turadigan ustunlar: № + o'quvchi ismi.
          SizedBox(
            width: numW + nameW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: numW,
                      height: rowH,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border(
                          bottom: BorderSide(color: c.border, width: 1.5),
                          right: BorderSide(color: c.border),
                        ),
                      ),
                      child: Text('№',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
                    ),
                    Container(
                      width: nameW,
                      height: rowH,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: c.surface2,
                        border: Border(
                          bottom: BorderSide(color: c.border, width: 1.5),
                          right: BorderSide(color: c.border, width: 1.5),
                        ),
                      ),
                      child: Text(
                        "O'quvchi",
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted),
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < students.length; i++)
                  Row(
                    children: [
                      Container(
                        width: numW,
                        height: heights[students[i].student.studentId],
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: c.border),
                            right: BorderSide(color: c.border),
                          ),
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.muted)),
                      ),
                      Container(
                        width: nameW,
                        height: heights[students[i].student.studentId],
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: c.border),
                            right: BorderSide(color: c.border, width: 1.5),
                          ),
                        ),
                        // Rang: 2+ oylik qarz BINAFSHA-PUSHTI, qarzdor QIZIL, to'lagan YASHIL —
                        // web bilan bir xil (`balanceColor`, app_theme.dart).
                        // MUHIM: balans ham, qarz oylari ham SHU GURUH bo'yicha (boshqa
                        // guruhdagi qarz bu yerni bo'yamaydi).
                        child: _StudentNameButton(
                          student: students[i].student,
                          style: nameStyle.copyWith(
                            color: balanceColor(
                              c,
                              students[i].student.balance,
                              students[i].student.debtMonths,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (final col in journal.columns)
                        _dateHeaderCell(context, col.date, cellW, rowH,
                            moved: rescheduled.containsKey(_dayKey(col.date))),
                      _totalHeaderCell(context, totalW, rowH),
                    ],
                  ),
                  for (final s in students)
                    Row(
                      children: [
                        for (final col in journal.columns)
                          _cell(context, journal, s.student, col.date, reasonById, cellW,
                              heights[s.student.studentId]!),
                        _totalCell(context, s, totalW, heights[s.student.studentId]!),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateHeaderCell(BuildContext context, String date, double w, double h, {bool moved = false}) {
    final c = AppTheme.of(context);
    final dt = DateTime.tryParse(date);
    final wd = dt != null ? _weekdayShort[(dt.weekday - 1) % 7] : '';
    final isToday = _dayKey(date) == _todayIso;
    return GestureDetector(
      onTap: () => _openBulk(date),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToday ? c.accentSoft : c.surface2,
          border: Border(
            bottom: BorderSide(color: c.border, width: 1.5),
            right: BorderSide(color: c.border),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  date.length >= 10 ? date.substring(8, 10) : date,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isToday ? c.accentD : c.text),
                ),
                // Ko'chirilgan dars ustuni — bosilganda asl kuniga qaytarish mumkin.
                if (moved) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.event_repeat_rounded, size: 11, color: c.accent),
                ],
              ],
            ),
            Text(wd, style: TextStyle(fontSize: 9.5, color: isToday ? c.accent : c.faint)),
          ],
        ),
      ),
    );
  }

  Widget _totalHeaderCell(BuildContext context, double w, double h) {
    final c = AppTheme.of(context);
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(bottom: BorderSide(color: c.border, width: 1.5)),
      ),
      child: Text('Jami', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
    );
  }

  Widget _cell(
    BuildContext context,
    GroupJournal journal,
    GroupJournalStudent s,
    String date,
    Map<String, AbsenceReason> reasonById,
    double w,
    double h,
  ) {
    final c = AppTheme.of(context);
    final entry = _entryFor(journal, s.studentId, date);
    final reasonId = entry?.reasonId;
    final reason = reasonId == null ? null : reasonById[reasonId];
    // P0-3: sabab KODI bo'lsa — o'quvchi KELMAGAN, sabab ro'yxatdan topilgan-topilmagani
    // muhim emas. (`/teacher/meta` yiqilsa yoki sabab Sozlamalardan o'chirilsa qidiruv
    // bo'sh qaytadi — ilgari bu butun tarixni yashil ✓ ga aylantirar edi.)
    final absent = reasonId != null;
    final disabled = _isBeforeStart(journal, s, date);
    final isToday = _dayKey(date) == _todayIso;
    // Keldi (yashil): dars o'tildi + baho yo'q + sabab yo'q + (ANIQ "keldi" belgisi BOR yoki
    // sana o'quvchi tizimga kiritilganidan (presentDefaultFrom) keyin) — orqaga sanalgan
    // a'zolikda ko'rib chiqilmagan darslar avto-"keldi" bo'lmaydi (web bilan bir xil).
    final present = !disabled &&
        entry?.grade == null &&
        !absent &&
        _isConducted(journal, date) &&
        ((entry?.present ?? false) ||
            s.presentDefaultFrom.isEmpty ||
            _dayKey(date).compareTo(_dayKey(s.presentDefaultFrom)) >= 0);

    Color? bg;
    Color fg;
    String label;

    if (disabled) {
      bg = c.surface3;
      fg = c.faint;
      label = '';
    } else if (entry?.grade != null) {
      // Baho rangi — butun tizimda yagona YASHIL shkala (1 och → 5 to'q), web bilan bir xil.
      bg = gradeCellBg(entry!.grade!);
      fg = gradeCellFg(entry.grade!);
      label = '${entry.grade}';
    } else if (absent) {
      // P1-6: KELMAGANLIK o'zlashtirish emojisidan USTUN — aks holda kelmagan
      // o'quvchi 🙋 bo'lib ko'rinib qolardi.
      final isLate = reason?.isLate ?? false;
      bg = isLate ? c.amberSoft : c.redSoft;
      fg = isLate ? c.amber : c.red;
      label = reason == null
          // Sabab nomi noma'lum (meta yiqilgan yoki sabab o'chirilgan) — lekin
          // "kelmadi" fakti YO'QOLMAYDI.
          ? '?'
          : (reason.short.isNotEmpty
              ? reason.short
              : (reason.name.length >= 2 ? reason.name.substring(0, 2) : reason.name));
    } else if (entry?.mastery != null) {
      final m = _masteryStyle(entry!.mastery!, c);
      bg = m.bg;
      fg = m.fg;
      label = m.label;
    } else if (present) {
      bg = c.greenSoft;
      fg = c.green;
      label = '✓';
    } else {
      bg = isToday ? c.accentSoft : null;
      fg = c.faint;
      label = '·';
    }

    return GestureDetector(
      onTap: disabled ? null : () => _openCell(journal, s, date),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border), right: BorderSide(color: c.border)),
        ),
        child: Container(
          width: w - 8,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  Widget _totalCell(BuildContext context, _ScoredStudent s, double w, double h) {
    final c = AppTheme.of(context);
    final total = s.combinedTotal;
    // P0-4: baholash yuklanmagan bo'lsa yig'indi TO'LIQ EMAS — 0 ni ham, jurnal-only
    // raqamni ham ishonchli qilib ko'rsatmaymiz, «—» chizamiz (tepada ogohlantirish bor).
    final known = !_gradingFailed && total > 0;
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Container(
        width: w - 10,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: known ? c.accentSoft : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          known ? '$total' : '—',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: known ? c.accentD : c.faint,
          ),
        ),
      ),
    );
  }

  /* ---------------- Davomat tabi ---------------- */

  /// Shu oy jurnalidan har o'quvchi bo'yicha davomat foizi (qo'shimcha so'rovsiz) —
  /// web `attendanceRows` bilan bir xil hisob.
  Widget _attendanceTab(BuildContext context, GroupJournal journal, List<_ScoredStudent> students) {
    final c = AppTheme.of(context);
    if (students.isEmpty) {
      return const EmptyState(text: "Bu guruhda faol o'quvchi yo'q.");
    }
    if (journal.conductedDates.isEmpty) {
      return EmptyState(text: "${fmtMonth(journal.month)} oyida o'tilgan dars yo'q.");
    }
    final lateIds = _lateReasonIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reasonsFailed) ...[
          _warnBanner(context,
              "Davomat sabablari yuklanmadi — foizlar to'liq bo'lmasligi mumkin."),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 17, color: c.accent),
              const SizedBox(width: 6),
              Text('Davomat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(width: 8),
              Text(fmtMonth(journal.month), style: TextStyle(fontSize: 12.5, color: c.faint)),
            ],
          ),
        ),
        SCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              // Sarlavha qatori.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Qator raqami — jurnal jadvalidagi «№» ustuni bilan bir xil (web ham shunday).
                    SizedBox(
                      width: 24,
                      child: Text('№',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
                    ),
                    Expanded(
                      child: Text("O'QUVCHI",
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
                    ),
                    _attHeaderCell(c, 'DARS'),
                    _attHeaderCell(c, 'KELDI'),
                    _attHeaderCell(c, 'KELMADI'),
                    SizedBox(
                      width: 54,
                      child: Text('DAVOMAT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              for (var i = 0; i < students.length; i++)
                _attendanceRow(c, journal, students[i].student, lateIds, i + 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attHeaderCell(AppColors c, String label) => SizedBox(
        width: 46,
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3)),
      );

  Widget _attendanceRow(
    AppColors c,
    GroupJournal journal,
    GroupJournalStudent st,
    Set<String> lateIds,
    int number,
  ) {
    // P1-4: jurnal gridi bilan AYNI qoida — grid «·» chizadigan darslar bu yerda
    // ham "keldi" deb sanalmaydi (a'zolik/guruh boshlanishi + `presentDefaultFrom`).
    final myConducted = journal.conductedDates
        .where((d) => _countsForAttendance(journal, st, d))
        .toList();
    final total = myConducted.length;
    var absences = 0;
    for (final d in myConducted) {
      final e = _entryFor(journal, st.studentId, d);
      // Sababli kelmagan darslar (kech qolgan MUSTASNO).
      if (e?.reasonId != null && !lateIds.contains(e!.reasonId)) absences++;
    }
    final present = total - absences;
    final percent = total > 0 ? (present / total * 100).round() : 0;

    final Color pctFg;
    final Color? pctBg;
    if (total == 0) {
      pctFg = c.faint;
      pctBg = null;
    } else if (percent >= 90) {
      pctFg = c.green;
      pctBg = c.greenSoft;
    } else if (percent >= 70) {
      pctFg = c.amber;
      pctBg = c.amberSoft;
    } else {
      pctFg = c.red;
      pctBg = c.redSoft;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$number',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
          ),
          Expanded(
            child: _StudentNameButton(
              student: st,
              maxLines: 2,
              // Web bilan bir xil: 2+ oylik qarz binafsha-pushti, qarzdor qizil,
              // to'lagan yashil (hammasi SHU GURUH bo'yicha).
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: balanceColor(c, st.balance, st.debtMonths),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text('$total',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
          ),
          SizedBox(
            width: 46,
            child: Text('$present',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.green)),
          ),
          SizedBox(
            width: 46,
            child: Text(absences == 0 ? '—' : '$absences',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: absences == 0 ? c.faint : c.red)),
          ),
          SizedBox(
            width: 54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: pctBg, borderRadius: BorderRadius.circular(8)),
                child: Text(total == 0 ? '—' : '$percent%',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: pctFg)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O'QUVCHI F.I.SH — BOSILADIGAN (jurnal va davomat tablarida bir xil).
///
/// Bosilganda o'quvchining surati oynada ochiladi (web `PhotoViewerModal` bilan
/// bir xil) — o'qituvchi o'quvchini yuzidan taniy olishi uchun. Surati BOR
/// o'quvchida ism yonida kichik ikonka turadi, ya'ni qayerda rasm borligi
/// ko'rinib turadi; surati yo'q bo'lsa ham oyna ochiladi va "Rasm yuklanmagan"
/// deb aytadi (jimgina hech nima bo'lmasligi chalg'itardi).
class _StudentNameButton extends StatelessWidget {
  final GroupJournalStudent student;
  final TextStyle style;
  final int? maxLines;
  const _StudentNameButton({required this.student, required this.style, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final hasPhoto = student.photoUrl.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showPhotoViewer(
        context,
        name: student.fullName,
        photoUrl: student.photoUrl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: Text(student.fullName, maxLines: maxLines, style: style)),
          if (hasPhoto) ...[
            const SizedBox(width: 4),
            Icon(Icons.image_outlined, size: 13, color: c.faint),
          ],
        ],
      ),
    );
  }
}

/// U1: buzuvchi amal oldidan tasdiq oynasi — namuna `group_tests_panel.dart:97-110`.
/// "Tozalash", "✗ Hammasi kelmadi" va "Asl kuniga qaytarish" bitta bosishda
/// qaytarib bo'lmaydigan ma'lumot yo'qotishga olib keladi.
Future<bool> _confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String okLabel,
}) async {
  final c = AppTheme.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okLabel, style: TextStyle(color: c.red)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Dars o'zlashtirish darajasi rangi/emoji (web `masteryDisplay`).
class _MasteryStyle {
  final String label;
  final Color bg;
  final Color fg;
  const _MasteryStyle(this.label, this.bg, this.fg);
}

_MasteryStyle _masteryStyle(int level, AppColors c) {
  switch (level) {
    case 0:
      return _MasteryStyle('😴', c.surface3, c.muted);
    case 1:
      return _MasteryStyle('👂', c.accentSoft, c.accent);
    case 2:
      return _MasteryStyle('🙋', c.greenSoft, c.green);
    case 3:
      return _MasteryStyle('⭐', c.amberSoft, c.amber);
    default:
      return _MasteryStyle('', c.surface2, c.faint);
  }
}

/// Katak (baho/davomat/uy vazifa/xulq/o'zlashtirish) tahrirlash natijasi.
class _CellSheetResult {
  final bool clear;
  final int? grade;
  final String? reasonId;
  final int homework;
  final int behavior;
  final int? mastery;
  /// ANIQ "keldi (bor)" belgisi.
  final bool present;
  const _CellSheetResult({
    this.clear = false,
    this.grade,
    this.reasonId,
    this.homework = 0,
    this.behavior = 0,
    this.mastery,
    this.present = false,
  });
}

/// Sarlavha sanasi varag'ining natijasi: ommaviy davomat yoki darsni ko'chirish.
enum _BulkKind { attendance, reschedule, cancelReschedule }

class _BulkResult {
  final _BulkKind kind;
  final bool absent;
  final String? reasonId;
  final String? toDate;
  final String? time;
  final String? rescheduleId;
  const _BulkResult.attendance(this.absent, this.reasonId)
      : kind = _BulkKind.attendance,
        toDate = null,
        time = null,
        rescheduleId = null;
  const _BulkResult.reschedule(this.toDate, this.time)
      : kind = _BulkKind.reschedule,
        absent = false,
        reasonId = null,
        rescheduleId = null;
  const _BulkResult.cancel(this.rescheduleId)
      : kind = _BulkKind.cancelReschedule,
        absent = false,
        reasonId = null,
        toDate = null,
        time = null;
}

/// Katakni bosganda pastdan chiquvchi tahrirlash varag'i — web `JournalCellModal.tsx` bilan bir xil:
/// baho, kech keldi, davomat («Keldi (bor)» + sabablar), uyga vazifa (qildi/chala/qilmadi),
/// xulq va darsga munosabat.
class _JournalCellSheet extends StatefulWidget {
  final String studentName;
  final String dateLabel;
  final JournalEntry? entry;
  final List<AbsenceReason> reasons;
  const _JournalCellSheet({
    required this.studentName,
    required this.dateLabel,
    required this.entry,
    required this.reasons,
  });

  @override
  State<_JournalCellSheet> createState() => _JournalCellSheetState();
}

class _JournalCellSheetState extends State<_JournalCellSheet> {
  int? _grade;
  String? _reasonId;
  int _homework = 0;
  int _behavior = 0;
  int? _mastery;
  bool _present = false;

  // Web `masteryOptions` bilan bir xil nomlar.
  static const List<(int, String, String)> _masteryOptions = [
    (0, 'Non-Reactive', 'Passiv, qayd qilmaydi'),
    (1, 'Reactive', 'Javob beradi, undama kerak'),
    (2, 'Active', 'Faol qatnashadi'),
    (3, 'Pro-Active', "Kuzatuvchi, o'zini o'rganadi"),
  ];

  @override
  void initState() {
    super.initState();
    _grade = widget.entry?.grade;
    _reasonId = widget.entry?.reasonId;
    _homework = widget.entry?.homework ?? 0;
    _behavior = widget.entry?.behavior ?? 0;
    _mastery = widget.entry?.mastery;
    _present = widget.entry?.present ?? false;
  }

  /// "Keldi" va "kelmadi (sabab)" bir vaqtda bo'lmaydi — biri tanlansa ikkinchisi o'chadi.
  void _toggleReason(String id) => setState(() {
        _reasonId = _reasonId == id ? null : id;
        if (_reasonId != null) {
          _present = false;
          // P1-6: kelmagan o'quvchida "darsga munosabat" ma'nosiz — «keldi»
          // bayrog'i kabi u ham tozalanadi. KECH KELGAN mustasno: u darsda
          // qatnashgan, munosabati ham, bahosi ham bo'lishi mumkin.
          final isLate = widget.reasons.any((r) => r.id == _reasonId && r.isLate);
          if (!isLate) _mastery = null;
        }
      });

  void _togglePresent() => setState(() {
        _present = !_present;
        if (_present) _reasonId = null;
      });

  void _toggleHomework(int v) => setState(() => _homework = _homework == v ? 0 : v);
  void _toggleBehavior(int v) => setState(() => _behavior = _behavior == v ? 0 : v);

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final lateReasons = widget.reasons.where((r) => r.isLate).toList();
    final absentReasons = widget.reasons.where((r) => !r.isLate).toList();
    final selectedLate = _reasonId != null && lateReasons.any((r) => r.id == _reasonId);
    final labelStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.faint, letterSpacing: 0.3);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text(widget.studentName, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 2),
            Text(widget.dateLabel, style: TextStyle(fontSize: 12, color: c.muted)),
            const SizedBox(height: 13),

            Text('BAHO', style: labelStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in [1, 2, 3, 4, 5]) ...[
                  Expanded(
                    child: _chipButton(
                      c,
                      label: '$g',
                      active: _grade == g,
                      // Yagona yashil shkala (web `gradeBadgeCls`).
                      activeColor: gradeCellBg(g),
                      activeFg: gradeCellFg(g),
                      onTap: () => setState(() => _grade = _grade == g ? null : g),
                    ),
                  ),
                  if (g != 5) const SizedBox(width: 6),
                ],
              ],
            ),

            if (lateReasons.isNotEmpty) ...[
              const SizedBox(height: 13),
              Text('KECH KELDI', style: labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in lateReasons)
                    _textChip(c, r.name, _reasonId == r.id, c.amber, c.amberSoft, () => _toggleReason(r.id)),
                ],
              ),
              if (selectedLate)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text("Kech kelgan — darsda qatnashgan, baho ham qo'yishingiz mumkin.",
                      style: TextStyle(fontSize: 11.5, color: c.amber)),
                ),
            ],

            const SizedBox(height: 13),
            Text('DAVOMAT', style: labelStyle),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _textChip(c, '✓ Keldi (bor)', _present, c.green, c.greenSoft, _togglePresent),
            ),
            const SizedBox(height: 8),
            absentReasons.isEmpty
                ? Text("Sabablar yo'q — Sozlamalarda qo'shing", style: TextStyle(fontSize: 12.5, color: c.faint))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in absentReasons)
                        _textChip(c, r.name, _reasonId == r.id, c.red, c.redSoft, () => _toggleReason(r.id)),
                    ],
                  ),

            const SizedBox(height: 13),
            Text('UYGA VAZIFA', style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _textChip(c, 'Qildi', _homework == 1, c.green, c.greenSoft, () => _toggleHomework(1)),
                _textChip(c, 'Chala qildi', _homework == 3, c.amber, c.amberSoft, () => _toggleHomework(3)),
                _textChip(c, 'Qilmadi', _homework == 2, c.red, c.redSoft, () => _toggleHomework(2)),
              ],
            ),

            const SizedBox(height: 13),
            Text('XULQ', style: labelStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                _textChip(c, 'Yaxshi', _behavior == 1, c.green, c.greenSoft, () => _toggleBehavior(1)),
                const SizedBox(width: 8),
                _textChip(c, 'Yomon', _behavior == 2, c.red, c.redSoft, () => _toggleBehavior(2)),
              ],
            ),

            const SizedBox(height: 13),
            Text('DARSGA MUNOSABAT', style: labelStyle),
            const SizedBox(height: 8),
            for (final opt in _masteryOptions) _masteryTile(c, opt.$1, opt.$2, opt.$3),
            if (_mastery != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _mastery = null),
                  child: Text('Tozalash', style: TextStyle(fontSize: 12, color: c.faint)),
                ),
              ),

            const SizedBox(height: 16),
            if (widget.entry != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SButton(
                  'Tozalash',
                  kind: BtnKind.danger,
                  large: true,
                  // U1: tasdiqsiz bosilsa baho + davomat + uy vazifa + xulq +
                  // o'zlashtirish BIRDANIGA yo'qolardi (tugma «Saqlash» ustida turadi).
                  onTap: () async {
                    final ok = await _confirmDestructive(
                      context,
                      title: 'Katakni tozalash',
                      message: "Bu katakdagi baho, davomat, uy vazifa, xulq va "
                          "darsga munosabat — hammasi o'chiriladi.",
                      okLabel: "Ha, o'chirilsin",
                    );
                    if (!ok || !context.mounted) return;
                    Navigator.of(context).pop(const _CellSheetResult(clear: true));
                  },
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: SButton(
                    'Bekor qilish',
                    kind: BtnKind.ghost,
                    large: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SButton(
                    'Saqlash',
                    large: true,
                    onTap: () => Navigator.of(context).pop(
                      _CellSheetResult(
                        grade: _grade,
                        reasonId: _reasonId,
                        homework: _homework,
                        behavior: _behavior,
                        mastery: _mastery,
                        present: _present,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipButton(
    AppColors c, {
    required String label,
    required bool active,
    required Color activeColor,
    required Color activeFg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? activeColor : c.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: active ? activeFg : c.text),
        ),
      ),
    );
  }

  Widget _textChip(AppColors c, String label, bool active, Color color, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? bg : c.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: active ? color : c.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : c.text),
        ),
      ),
    );
  }

  Widget _masteryTile(AppColors c, int value, String label, String desc) {
    final active = _mastery == value;
    return GestureDetector(
      onTap: () => setState(() => _mastery = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.accentSoft : c.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Row(
          children: [
            Icon(
              active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: active ? c.accent : c.faint,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: c.muted)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sarlavha sanasi bosilganda — hammaga birdan davomat + darsni boshqa kunga ko'chirish
/// (yoki ko'chirilgan darsni asl kuniga qaytarish). Web bulk modali bilan bir xil.
class _BulkAttendanceSheet extends StatefulWidget {
  final String date;
  final int count;
  final List<AbsenceReason> reasons;
  final String defaultTime;
  final LessonReschedule? reschedule;
  const _BulkAttendanceSheet({
    required this.date,
    required this.count,
    required this.reasons,
    required this.defaultTime,
    this.reschedule,
  });

  @override
  State<_BulkAttendanceSheet> createState() => _BulkAttendanceSheetState();
}

class _BulkAttendanceSheetState extends State<_BulkAttendanceSheet> {
  bool _moveOpen = false;
  DateTime? _toDate;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final t = widget.defaultTime;
    if (t.length >= 4 && t.contains(':')) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) _time = TimeOfDay(hour: h, minute: m);
    }
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final base = DateTime.tryParse(widget.date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? base,
      firstDate: DateTime(base.year - 1),
      lastDate: DateTime(base.year + 1),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final moved = widget.reschedule;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text('${fmtDate(widget.date, weekday: true)} — davomat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 8),
            Text(
              "Shu darsdagi ${widget.count} o'quvchiga birdan qo'llanadi.",
              style: TextStyle(fontSize: 13, color: c.muted),
            ),
            const SizedBox(height: 18),
            SButton(
              '✓ Hammasi keldi',
              large: true,
              onTap: () => Navigator.of(context).pop(const _BulkResult.attendance(false, null)),
            ),
            const SizedBox(height: 10),
            SButton(
              '✗ Hammasi kelmadi',
              kind: BtnKind.danger,
              large: true,
              // U1: «✓ Hammasi keldi» dan atigi 10px pastda turadi — tasodifan
              // bosilsa butun guruh yo'q deb belgilanardi.
              onTap: () async {
                final ok = await _confirmDestructive(
                  context,
                  title: 'Hammasi kelmadi',
                  message: "${widget.count} o'quvchining hammasi shu darsda KELMAGAN "
                      'deb belgilanadi.',
                  okLabel: 'Ha, belgilansin',
                );
                if (!ok || !context.mounted) return;
                Navigator.of(context).pop(const _BulkResult.attendance(true, null));
              },
            ),
            if (widget.reasons.isNotEmpty) ...[
              const SizedBox(height: 13),
              Text(
                'Yoki sabab bilan kelmadi:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in widget.reasons)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(_BulkResult.attendance(true, r.id)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.redSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(r.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.red)),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 14),

            // Darsni boshqa kunga ko'chirish (bir martalik) yoki asl kuniga qaytarish.
            if (moved != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.event_repeat_rounded, size: 17, color: c.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bu dars ${fmtDate(moved.fromDate)} dan ko\'chirilgan'
                      '${(moved.time ?? '').isEmpty ? '' : ' (${moved.time})'}.',
                      style: TextStyle(fontSize: 12.5, color: c.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SButton(
                'Asl kuniga qaytarish',
                icon: Icons.restore_rounded,
                kind: BtnKind.ghost,
                // U1: ko'chirish bekor qilinganda shu kundagi jurnal ustuni yo'qoladi.
                onTap: () async {
                  final ok = await _confirmDestructive(
                    context,
                    title: 'Asl kuniga qaytarish',
                    message: 'Bu dars ${fmtDate(moved.fromDate)} kuniga qaytariladi va '
                        "ko'chirilgan kun jurnaldan olib tashlanadi.",
                    okLabel: 'Ha, qaytarilsin',
                  );
                  if (!ok || !context.mounted) return;
                  Navigator.of(context).pop(_BulkResult.cancel(moved.id));
                },
              ),
            ] else if (!_moveOpen)
              SButton(
                'Darsni boshqa kunga ko\'chirish',
                icon: Icons.event_available_rounded,
                kind: BtnKind.soft,
                onTap: () => setState(() => _moveOpen = true),
              )
            else ...[
              Text('Darsni boshqa kunga ko\'chirish (bir martalik)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          _toDate == null ? 'Yangi sana' : fmtDate(_iso(_toDate!)),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _toDate == null ? c.faint : c.text),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          _time == null ? 'Vaqt (ixtiyoriy)' : _hhmm(_time!),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _time == null ? c.faint : c.text),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SButton(
                      "Ko'chirish",
                      icon: Icons.event_repeat_rounded,
                      onTap: _toDate == null
                          ? null
                          : () => Navigator.of(context).pop(
                                _BulkResult.reschedule(
                                    _iso(_toDate!), _time == null ? null : _hhmm(_time!)),
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SButton('Bekor', kind: BtnKind.ghost, onTap: () => setState(() => _moveOpen = false)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SButton('Yopish', kind: BtnKind.ghost, large: true, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
