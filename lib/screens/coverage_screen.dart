import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';

/// O'quv dasturi (dars o'tilishi) — guruh tanlab, o'quv dasturi bandlarini
/// (checklist) belgilash: o'tildi/o'tilmadi. Web `coverage/CoveragePage.tsx`ga
/// mos, lekin bu yerda interaktiv (web faqat progress ko'rsatadi).
class CoverageScreen extends StatefulWidget {
  const CoverageScreen({super.key});
  @override
  State<CoverageScreen> createState() => _CoverageScreenState();
}

class _CoverageScreenState extends State<CoverageScreen> {
  bool _loadingClasses = true;
  bool _loadingCurriculum = false;
  String? _error;
  List<TeacherClass> _classes = [];
  String? _selectedClassId;
  GroupCurriculum? _curriculum;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });
    try {
      final list = await TeacherApi.myClasses();
      if (!mounted) return;
      setState(() {
        _classes = list;
        _loadingClasses = false;
      });
      if (list.isNotEmpty) {
        _selectClass(list.first.classId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _error = "Guruhlarni yuklab bo'lmadi";
      });
    }
  }

  Future<void> _selectClass(String classId) async {
    setState(() {
      _selectedClassId = classId;
      _loadingCurriculum = true;
    });
    try {
      final c = await TeacherApi.groupCurriculum(classId);
      if (!mounted) return;
      setState(() {
        _curriculum = c;
        _loadingCurriculum = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _curriculum = null;
        _loadingCurriculum = false;
      });
    }
  }

  Future<void> _toggleItem(String itemId, bool covered) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    try {
      await TeacherApi.setGroupCover(classId, itemId, covered);
      await _selectClass(classId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Amalni bajarib bo'lmadi")));
    }
  }

  Future<void> _changeRevision(int delta) async {
    final classId = _selectedClassId;
    if (classId == null) return;
    try {
      await TeacherApi.changeGroupRevision(classId, delta);
      await _selectClass(classId);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Amalni bajarib bo'lmadi")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: "O'quv dasturi",
      child: _loadingClasses
          ? const Loader()
          : _error != null
              ? EmptyState(icon: Icons.error_outline, text: _error!)
              : _classes.isEmpty
                  ? const EmptyState(
                      icon: Icons.menu_book_outlined,
                      text: "Sizga biriktirilgan guruh yo'q",
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ClassPicker(
                          classes: _classes,
                          selected: _selectedClassId,
                          onSelect: _selectClass,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: _loadingCurriculum
                              ? const Loader()
                              : _curriculum == null
                                  ? const EmptyState(
                                      icon: Icons.error_outline,
                                      text: "Ma'lumot topilmadi",
                                    )
                                  : _CurriculumBody(
                                      curriculum: _curriculum!,
                                      onToggle: _toggleItem,
                                      onRevision: _changeRevision,
                                    ),
                        ),
                      ],
                    ),
    );
  }
}

class _ClassPicker extends StatelessWidget {
  final List<TeacherClass> classes;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ClassPicker({required this.classes, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cl = classes[i];
          final active = cl.classId == selected;
          return Material(
            color: active ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(cl.classId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? c.accent : c.border),
                ),
                child: Text(
                  cl.className,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : c.text,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CurriculumBody extends StatelessWidget {
  final GroupCurriculum curriculum;
  final Future<void> Function(String itemId, bool covered) onToggle;
  final Future<void> Function(int delta) onRevision;
  const _CurriculumBody({required this.curriculum, required this.onToggle, required this.onRevision});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final k = curriculum;
    final pct = k.totalItems > 0 ? (k.coveredCount / k.totalItems) : 0.0;
    final done = k.totalItems > 0 && k.remainingItems <= 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        SCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          k.courseName.isEmpty ? 'Dastur biriktirilmagan' : k.courseName,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text),
                        ),
                        const SizedBox(height: 2),
                        Text("O'tildi ${k.coveredCount}/${k.totalItems}",
                            style: TextStyle(fontSize: 12.5, color: c.muted)),
                      ],
                    ),
                  ),
                  Text('${(pct * 100).round()}%',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.accentD)),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(pct, color: c.accent),
              const SizedBox(height: 10),
              if (done)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: c.accentD, size: 18),
                    const SizedBox(width: 6),
                    Text('Kurs tugatildi!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accentD)),
                  ],
                )
              else
                Row(
                  children: [
                    Icon(Icons.schedule, color: c.faint, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '~${k.estLessonsLeft} dars qoldi'
                        '${k.estFinishDate != null ? " · ≈ ${fmtDate(k.estFinishDate)}" : ''}',
                        style: TextStyle(fontSize: 12.5, color: c.faint),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Takrorlash darslari',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
                    const SizedBox(height: 2),
                    Text('${k.revisionLessons} ta · haftasiga ${k.lessonsPerWeek} dars',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
              _StepBtn(icon: Icons.remove, onTap: () => onRevision(-1)),
              const SizedBox(width: 8),
              _StepBtn(icon: Icons.add, onTap: () => onRevision(1)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (k.levels.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            text: "Bu kursga dastur bandlari qo'shilmagan",
          ),
        for (final level in k.levels) _LevelSection(level: level, onToggle: onToggle),
      ],
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: c.surface3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: c.text)),
      ),
    );
  }
}

class _LevelSection extends StatelessWidget {
  final GroupCurriculumLevel level;
  final Future<void> Function(String itemId, bool covered) onToggle;
  const _LevelSection({required this.level, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(level.name),
          for (final topic in level.topics) _TopicSection(topic: topic, onToggle: onToggle),
        ],
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  final GroupCurriculumTopic topic;
  final Future<void> Function(String itemId, bool covered) onToggle;
  const _TopicSection({required this.topic, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(topic.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 6),
            for (final item in topic.items) _ItemRow(item: item, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  final GroupCurriculumItem item;
  final Future<void> Function(String itemId, bool covered) onToggle;
  const _ItemRow({required this.item, required this.onToggle});
  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onToggle(widget.item.id, !widget.item.covered);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final item = widget.item;
    return InkWell(
      onTap: _tap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
                  )
                : Icon(
                    item.covered ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: item.covered ? c.accentD : c.faint,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: item.covered ? c.muted : c.text,
                      decoration: item.covered ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (item.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.note, style: TextStyle(fontSize: 11.5, color: c.faint)),
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
