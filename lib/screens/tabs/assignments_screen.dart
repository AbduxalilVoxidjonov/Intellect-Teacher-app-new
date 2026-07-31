import 'package:flutter/material.dart';
import '../../api/teacher_api.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../assignment_detail_screen.dart';

/// Format bo'yicha ikona + rang (web `AssignmentsPage`dagi formatMeta bilan bir xil g'oya).
const Map<String, String> _formatLabel = {
  'written': 'Yozma',
  'file': 'Fayl',
  'test': 'Test',
  'video': 'Video',
  'speaking': 'Speaking',
};

const Map<String, IconData> _formatIcon = {
  'written': Icons.edit_outlined,
  'file': Icons.attach_file_rounded,
  'test': Icons.checklist_rounded,
  'video': Icons.videocam_outlined,
  'speaking': Icons.mic_none_rounded,
};

const Map<String, Color> _formatColor = {
  'written': Color(0xFF0284C7),
  'file': Color(0xFF7C3AED),
  'test': Color(0xFF0D9488),
  'video': Color(0xFFDB2777),
  'speaking': Color(0xFFD97706),
};

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  bool _loading = true;
  List<TeacherClass> _classes = [];
  List<Assignment> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([TeacherApi.myClasses(), TeacherApi.assignments()]);
      if (!mounted) return;
      setState(() {
        _classes = results[0] as List<TeacherClass>;
        _assignments = results[1] as List<Assignment>;
      });
    } catch (_) {
      // Xato bo'lsa bo'sh holat ko'rsatiladi.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentFormSheet(classes: _classes),
    );
    if (created == true) _load();
  }

  Future<void> _delete(Assignment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Topshiriqni o'chirish"),
        content: Text('"${a.title}" topshirig\'ini o\'chirasizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("O'chirish")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TeacherApi.deleteAssignment(a.id);
      if (!mounted) return;
      setState(() => _assignments.removeWhere((x) => x.id == a.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      children: [
        ScreenHeader(
          'Topshiriqlar',
          subtitle: Text('${_assignments.length} ta faol', style: TextStyle(fontSize: 12, color: c.muted)),
          trailing: (!_loading && _classes.isNotEmpty)
              ? _AddButton(onTap: _openForm)
              : null,
        ),
        Expanded(
          child: _loading
              ? const Loader()
              : _classes.isEmpty
                  ? const Center(child: EmptyState(text: 'Sizga biriktirilgan guruh/fan yo\'q.'))
                  : _assignments.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.assignment_outlined,
                            text: 'Hali topshiriq yo\'q. "+" tugmasi orqali yarating.',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: c.accent,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _assignments.length,
                            itemBuilder: (context, i) {
                              final a = _assignments[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AssignmentCard(
                                  a: a,
                                  onDelete: () => _delete(a),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        AssignmentDetailScreen(assignmentId: a.id, title: a.title),
                                  )),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: c.accent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const SizedBox(width: 42, height: 42, child: Icon(Icons.add_rounded, color: Colors.white)),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment a;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  const _AssignmentCard({required this.a, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final color = _formatColor[a.format] ?? c.accent;
    final overdue = a.dueDate != null && (DateTime.tryParse(a.dueDate!)?.isBefore(DateTime.now()) ?? false);
    return SCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(_formatIcon[a.format] ?? Icons.assignment_outlined, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_formatLabel[a.format] ?? a.format,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
                        if (a.subjectName.isNotEmpty) ...[
                          Text('  ·  ', style: TextStyle(color: c.faint, fontSize: 10.5)),
                          Expanded(
                            child: Text(a.subjectName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(a.title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline_rounded, size: 19, color: c.faint),
                ),
              ),
            ],
          ),
          if (a.classNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: a.classNames
                  .map((n) => SChip(n, color: c.text, bg: c.surface3))
                  .toList(),
            ),
          ],
          if (a.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(a.description.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: c.muted)),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(Icons.grade_outlined, size: 14, color: c.faint),
                const SizedBox(width: 4),
                Text('Maks: ', style: TextStyle(fontSize: 12, color: c.muted)),
                Text('${a.maxScore % 1 == 0 ? a.maxScore.toInt() : a.maxScore}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.text)),
                Text(' ball', style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: overdue ? c.red : c.faint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  a.dueDate != null ? fmtDate(a.dueDate, weekday: true) : "Muddat yo'q",
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: overdue ? c.red : c.muted),
                ),
              ),
              Icon(Icons.groups_2_outlined, size: 15, color: c.accent),
              const SizedBox(width: 4),
              Text('Kim bajardi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

InputDecoration _dec(AppColors c, String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.muted),
      filled: true,
      fillColor: c.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.5)),
    );

class _AssignmentFormSheet extends StatefulWidget {
  final List<TeacherClass> classes;
  const _AssignmentFormSheet({required this.classes});
  @override
  State<_AssignmentFormSheet> createState() => _AssignmentFormSheetState();
}

class _AssignmentFormSheetState extends State<_AssignmentFormSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _maxScore = TextEditingController(text: '100');
  TeacherClass? _group;
  Subject? _subject;
  String _format = 'written';
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) {
      _group = widget.classes.first;
      if (_group!.subjects.isNotEmpty) _subject = _group!.subjects.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _maxScore.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Sarlavha kiritilmagan');
      return;
    }
    if (_group == null || _subject == null) {
      setState(() => _error = "Guruh va kurs tanlanmagan");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final due = _dueDate == null
          ? null
          : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, 23, 59).toIso8601String();
      await TeacherApi.createAssignment(SaveAssignmentInput(
        subjectId: _subject!.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        format: _format,
        classIds: [_group!.classId],
        dueDate: due,
        lateAccept: false,
        latePenaltyPct: 0,
        maxScore: double.tryParse(_maxScore.text.trim()) ?? 100,
        autoGrade: false,
        materials: const [],
        questions: const [],
      ));
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Yangi topshiriq', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 16),
              TextField(controller: _title, style: TextStyle(color: c.text), decoration: _dec(c, 'Sarlavha')),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 3,
                style: TextStyle(color: c.text),
                decoration: _dec(c, 'Tavsif (ixtiyoriy)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TeacherClass>(
                initialValue: _group,
                decoration: _dec(c, 'Guruh'),
                items: widget.classes
                    .map((g) => DropdownMenuItem(value: g, child: Text(g.className)))
                    .toList(),
                onChanged: (g) => setState(() {
                  _group = g;
                  _subject = (g != null && g.subjects.isNotEmpty) ? g.subjects.first : null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Subject>(
                initialValue: _subject,
                decoration: _dec(c, 'Kurs'),
                items: (_group?.subjects ?? const <Subject>[])
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                    .toList(),
                onChanged: (s) => setState(() => _subject = s),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _format,
                decoration: _dec(c, 'Format'),
                items: _formatLabel.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (f) => setState(() => _format = f ?? 'written'),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _dec(c, 'Muddat (ixtiyoriy)'),
                  child: Text(
                    _dueDate == null ? "Tanlanmagan" : fmtDate(_dueDate!.toIso8601String(), weekday: true),
                    style: TextStyle(color: c.text),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxScore,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: c.text),
                decoration: _dec(c, 'Maksimal ball'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: c.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SButton('Saqlash', icon: Icons.check_rounded, loading: _saving, large: true, onTap: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
