import 'package:flutter/material.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Ball maydonidagi matnni songa aylantiradi.
///
/// TUZATILDI (P1-11): "8,5" (o'zbek/rus klaviaturasi taklif qiladigan vergulli
/// kasr) `double.tryParse` da `null` bo'lardi va ball JIMGINA saqlanmasdi —
/// oyna esa saqlangandek yopilardi. Yaroqsiz kirish uchun `null` qaytadi.
double? parseScoreInput(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return (v == null || !v.isFinite) ? null : v;
}

const Map<String, String> _formatLabel = {
  'written': 'Yozma',
  'file': 'Fayl',
  'test': 'Test',
  'video': 'Video',
  'speaking': 'Speaking',
};

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;
  final String title;
  const AssignmentDetailScreen({super.key, required this.assignmentId, this.title = 'Topshiriq'});
  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  bool _loading = true;
  AssignmentResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await TeacherApi.assignmentResults(widget.assignmentId);
      if (!mounted) return;
      setState(() => _result = r);
    } catch (_) {
      // Xato bo'lsa bo'sh holat ko'rsatiladi.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMark(SubmissionRow row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmissionSheet(
        assignmentId: widget.assignmentId,
        row: row,
        maxScore: _result?.maxScore ?? 100,
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: widget.title,
      child: _loading
          ? const Center(child: Loader())
          : _result == null
              ? const Center(child: EmptyState(text: "Ma'lumot topilmadi"))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: c.accent,
                  child: _buildBody(context, _result!),
                ),
    );
  }

  Widget _buildBody(BuildContext context, AssignmentResult r) {
    final c = AppTheme.of(context);
    final done = r.rows.where((x) => x.completed).toList();
    final pending = r.rows.where((x) => !x.completed).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatLabel[r.format] ?? r.format,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.accent)),
                    const SizedBox(height: 4),
                    Text('Maks: ${r.maxScore % 1 == 0 ? r.maxScore.toInt() : r.maxScore} ball',
                        style: TextStyle(fontSize: 13, color: c.muted)),
                  ],
                ),
              ),
              _StatBadge(label: 'Bajardi', value: '${r.completedCount}/${r.total}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle("Bajardi (${done.length})"),
        if (done.isEmpty)
          const EmptyState(icon: Icons.hourglass_empty_rounded, text: "Hali hech kim bajarmagan")
        else
          ...done.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudentRow(row: row, maxScore: r.maxScore, onTap: () => _openMark(row)),
              )),
        const SizedBox(height: 18),
        SectionTitle("Bajarmadi (${pending.length})"),
        if (pending.isEmpty)
          const EmptyState(icon: Icons.emoji_events_outlined, text: "Hammasi bajardi!")
        else
          ...pending.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudentRow(row: row, maxScore: r.maxScore, onTap: () => _openMark(row)),
              )),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.accent)),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.accentD)),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final SubmissionRow row;
  final double maxScore;
  final VoidCallback onTap;
  const _StudentRow({required this.row, required this.maxScore, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Avatar(name: row.studentName, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.studentName,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                if (row.className.isNotEmpty)
                  Text(row.className, style: TextStyle(fontSize: 12, color: c.muted)),
                if (row.completed && row.submittedAt != null)
                  Text('Topshirdi: ${fmtDate(row.submittedAt, weekday: true)}',
                      style: TextStyle(fontSize: 11, color: c.faint)),
              ],
            ),
          ),
          if (row.completed)
            // TUZATILDI (BUG-U2): bu 0–100 ball, jurnalning 1–5 bahosi EMAS.
            // `GradeBox` da 5 ham, 100 ham bir xil to'q yashil ko'rinar va
            // "87.5" 30×30 katakda jimgina kesilardi.
            ScoreBadge(score: row.score, maxScore: maxScore)
          else
            Icon(Icons.chevron_right_rounded, color: c.faint),
        ],
      ),
    );
  }
}

class _SubmissionSheet extends StatefulWidget {
  final String assignmentId;
  final SubmissionRow row;
  final double maxScore;
  const _SubmissionSheet({required this.assignmentId, required this.row, required this.maxScore});
  @override
  State<_SubmissionSheet> createState() => _SubmissionSheetState();
}

class _SubmissionSheetState extends State<_SubmissionSheet> {
  late bool _completed;
  late final TextEditingController _score;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completed = widget.row.completed;
    _score = TextEditingController(text: widget.row.score != null ? '${widget.row.score}' : '');
  }

  @override
  void dispose() {
    _score.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // TUZATILDI (P1-11):
    //  1) "8,5" `double.tryParse` da `null` bo'lib, ball JIMGINA saqlanmasdi;
    //  2) `maxScore` chegarasi tekshirilmasdi;
    //  3) manfiy ball qabul qilinardi;
    //  4) "Bajarmadi" tanlansa ham ball yuborilardi (maydon faqat `enabled: false`).
    final raw = _score.text.trim();
    double? score;
    if (_completed && raw.isNotEmpty) {
      score = parseScoreInput(raw);
      if (score == null) {
        setState(() => _error = "Ball noto'g'ri kiritilgan. Masalan: 8 yoki 8,5");
        return;
      }
      if (score < 0) {
        setState(() => _error = "Ball manfiy bo'lishi mumkin emas");
        return;
      }
      if (score > widget.maxScore) {
        final maxTxt = widget.maxScore % 1 == 0
            ? '${widget.maxScore.toInt()}'
            : '${widget.maxScore}';
        setState(() => _error = "Ball maksimaldan ($maxTxt) katta bo'lmasligi kerak");
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await TeacherApi.setSubmission(
        widget.assignmentId,
        widget.row.studentId,
        _completed,
        // "Bajarmadi" holatida ball umuman yuborilmaydi.
        score: score,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(color: c.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Avatar(name: widget.row.studentName, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.row.studentName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Bajarmadi',
                    active: !_completed,
                    color: c.red,
                    onTap: () => setState(() => _completed = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Bajardi',
                    active: _completed,
                    color: c.green,
                    onTap: () => setState(() => _completed = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _score,
              enabled: _completed,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: c.text),
              decoration: InputDecoration(
                labelText: 'Ball (maks ${widget.maxScore % 1 == 0 ? widget.maxScore.toInt() : widget.maxScore})',
                labelStyle: TextStyle(color: c.muted),
                filled: true,
                fillColor: c.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: c.red, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SButton('Saqlash', icon: Icons.check_rounded, loading: _saving, large: true, onTap: _save),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: active ? color.withValues(alpha: 0.14) : c.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? color : c.border),
          ),
          child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w700, color: active ? color : c.muted, fontSize: 13.5)),
        ),
      ),
    );
  }
}
