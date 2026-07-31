import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/teacher_api.dart';

/// Ta'lim progresi — har bir guruh uchun shu oydagi natija: o'rtacha baho,
/// qo'yilgan baholar soni, davomatsizlik. Web `learning/LearningPage.tsx`ga mos.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _GroupStat {
  final String classId;
  final String className;
  final int studentsCount;
  final int gradesCount;
  final double avgGrade;
  final int absencesCount;
  _GroupStat({
    required this.classId,
    required this.className,
    required this.studentsCount,
    required this.gradesCount,
    required this.avgGrade,
    required this.absencesCount,
  });
}

class _LearningScreenState extends State<LearningScreen> {
  bool _loading = true;
  String? _error;
  List<_GroupStat> _groups = [];
  late final String _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await TeacherApi.myClasses();
      final results = <_GroupStat>[];
      for (final cls in classes) {
        try {
          final j = await TeacherApi.groupJournal(cls.classId, month: _month);
          final gradeEntries = j.entries.where((e) => e.grade != null).toList();
          final gradesCount = gradeEntries.length;
          final sum = gradeEntries.fold<int>(0, (acc, e) => acc + (e.grade ?? 0));
          final avg = gradesCount == 0 ? 0.0 : sum / gradesCount;
          final absencesCount = j.entries.where((e) => e.reasonId != null).length;
          results.add(_GroupStat(
            classId: cls.classId,
            className: cls.className,
            studentsCount: j.students.length,
            gradesCount: gradesCount,
            avgGrade: avg,
            absencesCount: absencesCount,
          ));
        } catch (_) {
          // shu guruhni o'tkazib yuboramiz
        }
      }
      if (!mounted) return;
      setState(() {
        _groups = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Ma'lumotlarni yuklab bo'lmadi";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: "O'quv materiallari",
      child: _loading
          ? const Loader()
          : _error != null
              ? EmptyState(icon: Icons.error_outline, text: _error!)
              : _groups.isEmpty
                  ? const EmptyState(
                      icon: Icons.school_outlined,
                      text: "Sizga biriktirilgan guruh yo'q",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _groups.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GroupCard(stat: _groups[i], month: _month),
                      ),
                    ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final _GroupStat stat;
  final String month;
  const _GroupCard({required this.stat, required this.month});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.school_rounded, color: c.accentD, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.className,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                    Text("${stat.studentsCount} o'quvchi · ${fmtMonth(month)}",
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stat.gradesCount == 0)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
              child: Text("Bu oyda baho qo'yilmagan",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(stat.avgGrade.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800, color: gradeColor(stat.avgGrade))),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("o'rtacha baho",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Baholar', value: '${stat.gradesCount}')),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Davomatsizlik', value: '${stat.absencesCount}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
        ],
      ),
    );
  }
}
