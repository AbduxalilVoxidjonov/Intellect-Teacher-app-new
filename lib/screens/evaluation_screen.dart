import 'package:flutter/material.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// O'z faningiz bo'yicha o'quvchilarga baholash turlari kesimida 1-5 baho
/// qo'yish jadvali (guruh + fan + oy tanlab). Web: `evaluation/EvaluationPage.tsx`.
class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({super.key});
  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  List<TeacherClass> _classes = [];
  String _classId = '';
  String _subjectId = '';
  String _month = '';
  EvaluationBoard? _board;
  bool _loading = true;
  bool _boardLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final classes = await TeacherApi.myClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classId = classes.isNotEmpty ? classes.first.classId : '';
        _subjectId = _subjectsOf(_classId).isNotEmpty ? _subjectsOf(_classId).first.id : '';
      });
      await _loadBoard();
    } catch (_) {
      // bo'sh ro'yxat bilan qoladi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Subject> _subjectsOf(String classId) {
    for (final c in _classes) {
      if (c.classId == classId) return c.subjects;
    }
    return const [];
  }

  Future<void> _loadBoard({String? month}) async {
    if (_classId.isEmpty || _subjectId.isEmpty) {
      setState(() => _board = null);
      return;
    }
    setState(() => _boardLoading = true);
    try {
      final b = await TeacherApi.evalBoard(_classId, _subjectId, month: month);
      if (!mounted) return;
      setState(() {
        _board = b;
        _month = b.month;
      });
    } catch (_) {
      if (mounted) setState(() => _board = null);
    } finally {
      if (mounted) setState(() => _boardLoading = false);
    }
  }

  void _onClassChanged(String classId) {
    final subs = _subjectsOf(classId);
    setState(() {
      _classId = classId;
      _subjectId = subs.isNotEmpty ? subs.first.id : '';
    });
    _loadBoard();
  }

  void _onSubjectChanged(String subjectId) {
    setState(() => _subjectId = subjectId);
    _loadBoard();
  }

  void _onMonthChanged(String month) {
    setState(() => _month = month);
    _loadBoard(month: month);
  }

  Future<void> _pickGrade(EvaluationRow row, EvaluationType type) async {
    final c = AppTheme.of(context);
    final current = row.grades[type.id];
    final result = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cc = AppTheme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cc.text)),
                const SizedBox(height: 4),
                Text(row.fullName, style: TextStyle(fontSize: 13, color: cc.muted)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var n = 1; n <= 5; n++)
                      _GradeChoice(score: n, selected: current == n, onTap: () => Navigator.of(ctx).pop(n)),
                  ],
                ),
                if (current != null) ...[
                  const SizedBox(height: 14),
                  SButton("Tozalash", kind: BtnKind.ghost, onTap: () => Navigator.of(ctx).pop(-1)),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    final score = result == -1 ? null : result;
    try {
      await TeacherApi.setEvalGrade(_classId, _subjectId, row.studentId, type.id, _month, score);
      await _loadBoard(month: _month);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bahoni saqlashda xatolik')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final board = _board;

    Widget body;
    if (_loading) {
      body = const Center(child: Loader());
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          Text(
            "O'z faningiz bo'yicha o'quvchilarga baholash turlari kesimida baho qo'ying (1-5, oylik)",
            style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterDropdown<String>(
                  label: 'Guruh',
                  value: _classId.isEmpty ? null : _classId,
                  items: [for (final cl in _classes) DropdownMenuItem(value: cl.classId, child: Text(cl.className))],
                  onChanged: (v) => v == null ? null : _onClassChanged(v),
                  emptyHint: "guruh yo'q",
                ),
                const SizedBox(width: 8),
                _FilterDropdown<String>(
                  label: 'Fan',
                  value: _subjectId.isEmpty ? null : _subjectId,
                  items: [for (final s in _subjectsOf(_classId)) DropdownMenuItem(value: s.id, child: Text(s.name))],
                  onChanged: (v) => v == null ? null : _onSubjectChanged(v),
                  emptyHint: "fan yo'q",
                ),
                const SizedBox(width: 8),
                _FilterDropdown<String>(
                  label: 'Oy',
                  value: _month.isEmpty ? null : _month,
                  items: [
                    for (final m in (board?.months.isNotEmpty ?? false) ? board!.months : (_month.isNotEmpty ? [_month] : <String>[]))
                      DropdownMenuItem(value: m, child: Text(fmtMonth(m))),
                  ],
                  onChanged: (v) => v == null ? null : _onMonthChanged(v),
                  emptyHint: '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_boardLoading)
            const Padding(padding: EdgeInsets.only(top: 40), child: Loader())
          else if (_classId.isEmpty || _subjectId.isEmpty)
            const EmptyState(icon: Icons.school_outlined, text: 'Guruh va fan tanlang')
          else if (board == null || board.types.isEmpty)
            const EmptyState(
              icon: Icons.checklist_rounded,
              text: "Hali baholash turi yo'q — administrator qo'shgach shu yerda 1-5 baho qo'yasiz.",
            )
          else if (board.rows.isEmpty)
            const EmptyState(icon: Icons.groups_outlined, text: "Bu guruhda o'quvchi yo'q")
          else
            _EvalTable(board: board, onCellTap: _pickGrade),
        ],
      );
    }

    return SubScaffold(title: 'Baholash', child: body);
  }
}

class _GradeChoice extends StatelessWidget {
  final int score;
  final bool selected;
  final VoidCallback onTap;
  const _GradeChoice({required this.score, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final col = gradeColor(score);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? col : col.withValues(alpha: 0.13),
          border: Border.all(color: col, width: selected ? 0 : 1.4),
        ),
        child: Text(
          '$score',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: selected ? Colors.white : col),
        ),
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String emptyHint;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.emptyHint,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          items.isEmpty
              ? Text(emptyHint, style: TextStyle(fontSize: 13, color: c.faint))
              : DropdownButton<T>(
                  value: value,
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
                  items: items,
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}

class _EvalTable extends StatelessWidget {
  final EvaluationBoard board;
  final void Function(EvaluationRow row, EvaluationType type) onCellTap;
  const _EvalTable({required this.board, required this.onCellTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(c.surface2),
          headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.muted),
          dataTextStyle: TextStyle(fontSize: 13, color: c.text),
          columnSpacing: 20,
          columns: [
            const DataColumn(label: Text('№')),
            const DataColumn(label: Text('F.I.Sh.')),
            for (final t in board.types) DataColumn(label: Tooltip(message: t.description, child: Text(t.name))),
            const DataColumn(label: Text("O'rtacha")),
          ],
          rows: [
            for (var i = 0; i < board.rows.length; i++)
              DataRow(cells: [
                DataCell(Text('${i + 1}', style: TextStyle(color: c.faint))),
                DataCell(Text(board.rows[i].fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                for (final t in board.types)
                  DataCell(
                    GestureDetector(
                      onTap: () => onCellTap(board.rows[i], t),
                      child: GradeBox(board.rows[i].grades[t.id]),
                    ),
                  ),
                DataCell(
                  board.rows[i].avgGrade > 0
                      ? Text(
                          board.rows[i].avgGrade % 1 == 0
                              ? '${board.rows[i].avgGrade.toInt()}'
                              : '${board.rows[i].avgGrade}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: c.text),
                        )
                      : Text('—', style: TextStyle(color: c.faint)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
