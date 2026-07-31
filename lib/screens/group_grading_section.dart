import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

const _weekdayShort = ['Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha', 'Ya'];

/// Guruh BAHOLASH bo'limi — web `components/grading/GradingSection.tsx` ning to'liq ko'chirmasi:
/// oy tanlash → dars sanasi tanlash → mezonlar bo'yicha har o'quvchiga "bajardi/bajarmadi",
/// mezon sarlavhasiga bosilsa shu sanada BARCHAGA belgilash/belgilamaslik.
///
/// DIQQAT (joylashuv): web'da ham jadval ustunlari MEZONLAR, sana esa yuqoridagi
/// chiplardan tanlanadi (jurnaldagidek). Telefon ekranida 20+ sana × mezon jadvali
/// sig'magani uchun aynan shu mantiq saqlangan: sanalar — gorizontal scroll'li chiplar,
/// jadvalda chapda yopishib turgan o'quvchi ustuni + gorizontal scroll'li mezon ustunlari.
///
/// Widget O'ZI vertikal scroll qilmaydi (chaqiruvchi sahifa `SingleChildScrollView` beradi).
class GroupGradingSection extends StatefulWidget {
  final String groupId;

  /// Boshlanishida tanlanadigan oy ("yyyy-MM"); null bo'lsa server bergan joriy oy.
  final String? initialMonth;

  const GroupGradingSection({super.key, required this.groupId, this.initialMonth});

  @override
  State<GroupGradingSection> createState() => _GroupGradingSectionState();
}

class _GroupGradingSectionState extends State<GroupGradingSection> {
  GradingBoard? _board;
  bool _loading = true;
  String? _error;

  /// Tanlangan dars sanasi ("yyyy-MM-dd").
  String _date = '';

  /// Web bilan bir xil kalit shakli: "studentId|criterionId|date".
  final Set<String> _done = <String>{};

  /// Saqlanayotgan kataklar — katakda kichik yuklanish belgisi ko'rsatiladi.
  final Set<String> _saving = <String>{};

  /// Ommaviy (bulk) belgilash davomida butun bo'lim bosishga berk bo'ladi.
  bool _bulkSaving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.initialMonth);
  }

  String get _todayIso {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  /// `silent` — bulk'dan keyin qayta yuklash: jadval o'rnini Loader egallamaydi.
  Future<void> _load(String? month, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final b = await TeacherApi.gradingBoard(widget.groupId, month: month);
      if (!mounted) return;
      setState(() {
        _board = b;
        _loading = false;
        _error = null;
        // Web bilan bir xil: avvalgi sana shu oyda bo'lsa saqlanadi, bo'lmasa bugun,
        // aks holda oyning oxirgi dars kuni tanlanadi.
        _date = b.dates.contains(_date)
            ? _date
            : b.dates.contains(_todayIso)
                ? _todayIso
                : (b.dates.isEmpty ? '' : b.dates.last);
        _done
          ..clear()
          ..addAll(
            b.students.expand((st) => st.doneKeys.map((k) => '${st.studentId}|$k')),
          );
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _loading = false;
        // Taxta allaqachon ko'rinib turgan bo'lsa uni yo'qotmaymiz — faqat xabar beramiz.
        if (_board == null) _error = msg;
      });
      if (_board != null) _toast(msg);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Katakni bosish — optimistik belgilash, xatoda avvalgi holatga qaytarish.
  Future<void> _toggle(GradingBoardStudent s, GradingBoardCriterion cr) async {
    if (_date.isEmpty) return;
    final key = '${s.studentId}|${cr.id}|$_date';
    if (_saving.contains(key)) return;
    final next = !_done.contains(key);
    setState(() {
      if (next) {
        _done.add(key);
      } else {
        _done.remove(key);
      }
      _saving.add(key);
    });
    try {
      await TeacherApi.setGrade(SetGrade(
        groupId: widget.groupId,
        studentId: s.studentId,
        criterionId: cr.id,
        date: _date,
        done: next,
      ));
    } catch (e) {
      // Saqlanmadi (masalan, a'zolik boshlanishidan oldingi sana) — belgini qaytaramiz.
      if (!mounted) return;
      setState(() {
        if (next) {
          _done.remove(key);
        } else {
          _done.add(key);
        }
      });
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  /// Mezon sarlavhasi bosilganda — shu sanada hammaga belgilash/belgilamaslik
  /// (web'dagi sarlavha menyusi; telefonda pastdan chiquvchi varaq).
  Future<void> _openBulk(GradingBoardCriterion cr) async {
    final board = _board;
    if (board == null || _date.isEmpty || board.students.isEmpty) return;
    final c = AppTheme.of(context);
    final value = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _GradingBulkSheet(
        criterionName: cr.name,
        dateLabel: fmtDate(_date, weekday: true),
        count: board.students.length,
      ),
    );
    if (value == null || !mounted) return;
    final prev = Set<String>.from(_done);
    setState(() {
      _bulkSaving = true;
      for (final st in board.students) {
        final key = '${st.studentId}|${cr.id}|$_date';
        if (value) {
          _done.add(key);
        } else {
          _done.remove(key);
        }
      }
    });
    try {
      await TeacherApi.bulkGrade(BulkGrade(
        groupId: widget.groupId,
        criterionId: cr.id,
        date: _date,
        done: value,
      ));
      // Backend a'zoligi shu sanadan keyin boshlangan o'quvchini o'tkazib yuboradi
      // (ilova modelida `memberStart` yo'q) — haqiqiy holatni serverdan qayta o'qiymiz.
      await _load(board.month, silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _done
          ..clear()
          ..addAll(prev);
      });
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _bulkSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bulk saqlanayotganda bosishlar bloklanadi (ikki marta yuborilmasligi uchun).
    return AbsorbPointer(
      absorbing: _bulkSaving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _content(context),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    if (_error != null && _board == null) {
      return [EmptyState(icon: Icons.error_outline, text: _error!)];
    }
    final board = _board;
    if (_loading && board == null) {
      return const [
        SizedBox(height: 180, child: Loader(label: 'Yuklanmoqda...')),
      ];
    }
    if (board == null) {
      return const [EmptyState(text: 'Baholash maʼlumoti topilmadi')];
    }

    final out = <Widget>[];
    if (board.months.isNotEmpty) {
      out
        ..add(_monthChips(context, board))
        ..add(const SizedBox(height: 10));
    }

    if (board.criteria.isEmpty) {
      // Web bilan bir xil matn: mezon biriktirilmagan bo'lsa jadval umuman yo'q.
      out.add(const EmptyState(
        icon: Icons.fact_check_outlined,
        text: "Baholash mezoni biriktirilmagan.\nO'quv bo'limi → Baholash mezonlari "
            "bo'limidan bu guruhga mezon biriktiring.",
      ));
      return out;
    }
    if (board.dates.isEmpty) {
      out.add(EmptyState(
        icon: Icons.event_busy_outlined,
        text: '${fmtMonth(board.month)} oyida dars kuni yo\'q.',
      ));
      return out;
    }

    out
      ..add(_dateStrip(context, board))
      ..add(const SizedBox(height: 10));

    if (board.students.isEmpty) {
      out.add(const EmptyState(
        icon: Icons.groups_outlined,
        text: "Guruhda faol o'quvchi yo'q.",
      ));
      return out;
    }

    out
      ..add(_summaryCard(context, board))
      ..add(const SizedBox(height: 10))
      ..add(_grid(context, board));
    if (_loading) {
      // Oy almashganda jadval joyida qoladi, ustiga faqat kichik indikator qo'shiladi.
      out
        ..add(const SizedBox(height: 10))
        ..add(const SizedBox(height: 34, child: Loader()));
    }
    return out;
  }

  /// Oylar — gorizontal chiplar (tanlangani `accent` fon, oq matn).
  Widget _monthChips(BuildContext context, GradingBoard board) {
    final c = AppTheme.of(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: board.months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final m = board.months[i];
          final active = m == board.month;
          return GestureDetector(
            onTap: active ? null : () => _load(m),
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

  /// Dars sanalari — web'dagidek (hafta kuni + kun raqami) gorizontal tasma.
  Widget _dateStrip(BuildContext context, GradingBoard board) {
    final c = AppTheme.of(context);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: board.dates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final d = board.dates[i];
          final sel = d == _date;
          final isToday = d == _todayIso;
          final dt = DateTime.tryParse(d);
          final wd = dt != null ? _weekdayShort[(dt.weekday - 1) % 7] : '';
          return GestureDetector(
            onTap: () => setState(() => _date = d),
            child: Container(
              width: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? c.accent : (isToday ? c.accentSoft : c.surface2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? c.accent : (isToday ? c.accent : c.border)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    wd,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white70 : (isToday ? c.accent : c.faint),
                    ),
                  ),
                  Text(
                    d.length >= 10 ? d.substring(8, 10) : d,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: sel ? Colors.white : (isToday ? c.accentD : c.text),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bitta o'quvchining OY bo'yicha bajargan mezonlari soni.
  int _monthDone(String studentId) {
    final prefix = '$studentId|';
    var n = 0;
    for (final k in _done) {
      if (k.startsWith(prefix)) n++;
    }
    return n;
  }

  /// Oy bo'yicha umumiy bajarilish (jami / dates × criteria × o'quvchilar) va foiz.
  Widget _summaryCard(BuildContext context, GradingBoard board) {
    final c = AppTheme.of(context);
    final perStudent = board.dates.length * board.criteria.length;
    final total = perStudent * board.students.length;
    final done = _done.length;
    final pct = total == 0 ? 0 : (done * 100 / total).round();
    return SCard(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fmtDate(_date, weekday: true),
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                ),
              ),
              SChip('$done / $total · $pct%', color: c.accent),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(total == 0 ? 0 : done / total, height: 7),
          const SizedBox(height: 6),
          Text(
            "Har o'quvchi uchun oyda $perStudent belgi "
            '(${board.dates.length} dars × ${board.criteria.length} mezon).',
            style: TextStyle(fontSize: 11, color: c.muted),
          ),
        ],
      ),
    );
  }

  /// Asosiy jadval: chapda yopishib turgan o'quvchi ustuni, o'ngda gorizontal
  /// scroll'li mezon ustunlari + "Jami" (tanlangan sana bo'yicha).
  Widget _grid(BuildContext context, GradingBoard board) {
    final c = AppTheme.of(context);
    const nameW = 132.0;
    const cellW = 92.0;
    const totalW = 52.0;
    const headH = 54.0;

    final perStudent = board.dates.length * board.criteria.length;
    // Uslub `DefaultTextStyle`dan MEROS OLMAYDI (`inherit: false`) — meros olinganda
    // ism ostida begona chiziq (underline) paydo bo'lishi mumkin; jurnal jadvalidagi
    // ism ustuni bilan bir xil qoida.
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

    // Ism to'liq (tag-ma-tag) chiqishi uchun har qatorning balandligini o'lchaymiz —
    // group_detail_screen jurnalidagi kabi; border/padding zaxirasi bilan.
    double rowHeight(String name) {
      final tp = TextPainter(
        text: TextSpan(text: name.isEmpty ? '—' : name, style: nameStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: nameW - 24);
      return math.max(54.0, tp.height + 30);
    }

    final heights = <String, double>{
      for (final s in board.students) s.studentId: rowHeight(s.fullName),
    };

    return SCard(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: nameW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: headH,
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
                for (final s in board.students)
                  Container(
                    height: heights[s.studentId],
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: c.border),
                        right: BorderSide(color: c.border, width: 1.5),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: nameStyle),
                        // Oy bo'yicha bajarilgan / jami va foiz — har o'quvchi uchun.
                        Text(
                          _progressLabel(_monthDone(s.studentId), perStudent),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.faint),
                        ),
                      ],
                    ),
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
                      for (final cr in board.criteria)
                        _criterionHeader(context, cr, cellW, headH),
                      Container(
                        width: totalW,
                        height: headH,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.surface2,
                          border: Border(bottom: BorderSide(color: c.border, width: 1.5)),
                        ),
                        child: Text(
                          'Jami',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final s in board.students)
                    Row(
                      children: [
                        for (final cr in board.criteria)
                          _checkCell(context, s, cr, cellW, heights[s.studentId]!),
                        _dayTotalCell(context, board, s, totalW, heights[s.studentId]!),
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

  String _progressLabel(int done, int total) {
    if (total == 0) return '—';
    return '$done/$total · ${(done * 100 / total).round()}%';
  }

  /// Mezon sarlavhasi — bosilsa ommaviy belgilash varag'i ochiladi (web menyusi kabi).
  Widget _criterionHeader(BuildContext context, GradingBoardCriterion cr, double w, double h) {
    final c = AppTheme.of(context);
    return GestureDetector(
      onTap: () => _openBulk(cr),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border(
            bottom: BorderSide(color: c.border, width: 1.5),
            right: BorderSide(color: c.border),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cr.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text),
            ),
            Icon(Icons.keyboard_arrow_down, size: 13, color: c.faint),
          ],
        ),
      ),
    );
  }

  /// "Bajardi/bajarmadi" katagi — bosilganda darhol belgilanadi (optimistik).
  Widget _checkCell(
    BuildContext context,
    GradingBoardStudent s,
    GradingBoardCriterion cr,
    double w,
    double h,
  ) {
    final c = AppTheme.of(context);
    final key = '${s.studentId}|${cr.id}|$_date';
    final isDone = _done.contains(key);
    final saving = _saving.contains(key);
    return GestureDetector(
      onTap: saving ? null : () => _toggle(s, cr),
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.border),
            right: BorderSide(color: c.border),
          ),
        ),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDone ? c.green : c.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: isDone ? c.green : c.borderStrong, width: 1.4),
          ),
          child: saving
              // Saqlanayotganda katakda kichik yuklanish belgisi.
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDone ? Colors.white : c.accent,
                  ),
                )
              : Icon(
                  Icons.check,
                  size: 17,
                  color: isDone ? Colors.white : Colors.transparent,
                ),
        ),
      ),
    );
  }

  /// Tanlangan sanada shu o'quvchi bajargan mezonlar soni (web'dagi "Jami" ustuni).
  Widget _dayTotalCell(
    BuildContext context,
    GradingBoard board,
    GradingBoardStudent s,
    double w,
    double h,
  ) {
    final c = AppTheme.of(context);
    var n = 0;
    for (final cr in board.criteria) {
      if (_done.contains('${s.studentId}|${cr.id}|$_date')) n++;
    }
    return Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: n > 0 ? c.accentSoft : null,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          n > 0 ? '$n' : '—',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: n > 0 ? c.accentD : c.faint,
          ),
        ),
      ),
    );
  }
}

/// Mezon sarlavhasi bosilganda — shu darsda barcha o'quvchiga birdan belgilash/belgilamaslik
/// (web'dagi "Hammaga belgilash / Belgilamaslik" menyusining telefon varianti).
class _GradingBulkSheet extends StatelessWidget {
  final String criterionName;
  final String dateLabel;
  final int count;
  const _GradingBulkSheet({
    required this.criterionName,
    required this.dateLabel,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
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
          Text(
            criterionName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            "$dateLabel — shu darsdagi $count o'quvchiga birdan qo'llanadi.",
            style: TextStyle(fontSize: 13, color: c.muted),
          ),
          const SizedBox(height: 18),
          SButton(
            'Hammaga belgilash',
            icon: Icons.check,
            large: true,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          SButton(
            'Belgilamaslik',
            icon: Icons.close,
            kind: BtnKind.danger,
            large: true,
            onTap: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 14),
          SButton(
            'Yopish',
            kind: BtnKind.ghost,
            large: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
