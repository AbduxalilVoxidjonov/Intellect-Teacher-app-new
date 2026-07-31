import 'package:flutter/material.dart';

import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import 'group_tests_panel.dart';

/// «Testlar» TAB (pastki navigatsiya) — web `TeacherTestsPage.tsx` bilan bir xil:
/// avval guruh tanlanadi, keyin shu guruh testlari (yaratish/tahrirlash/ball qo'yish)
/// [GroupTestsPanel] orqali ko'rsatiladi. Panel guruh (jurnal) sahifasidagi
/// «Imtihonlar» tabida ham AYNAN shu ko'rinishda ishlaydi.
class TestsScreen extends StatefulWidget {
  /// Pastki navigatsiya tabida — orqaga tugmasi shart emas (root).
  final bool showBack;
  const TestsScreen({super.key, this.showBack = false});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  bool _loading = true;
  String? _error;
  List<TeacherClass> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await TeacherApi.myClasses();
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final body = _loading
        ? const Center(child: Loader())
        : _error != null
            ? EmptyState(icon: Icons.error_outline_rounded, text: _error!)
            : _classes.isEmpty
                ? const EmptyState(
                    icon: Icons.groups_outlined, text: "Sizga biriktirilgan guruh yo'q.")
                : RefreshIndicator(
                    color: c.accent,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text('Guruhni tanlang', style: TextStyle(fontSize: 13, color: c.muted)),
                        const SizedBox(height: 10),
                        for (final g in _classes) ...[
                          _groupCard(c, g),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  );

    // Root tab bo'lganda ScreenHeader (katta sarlavha), ichki ekran bo'lganda SubScaffold.
    if (widget.showBack) {
      return SubScaffold(title: 'Testlar', child: body);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(
          'Testlar',
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              "Onlayn (bot) yoki oflayn test yaratish va natijalarni kiritish",
              style: TextStyle(fontSize: 12.5, color: c.muted),
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _groupCard(AppColors c, TeacherClass g) {
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _GroupTestsScreen(group: g)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Text(initials(g.className),
                style: TextStyle(fontWeight: FontWeight.w800, color: c.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.className,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                if (g.subjects.isNotEmpty)
                  Text(g.subjects.map((s) => s.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.faint),
        ],
      ),
    );
  }
}

/// Bitta guruh testlari — panel tashqi scroll ichida beriladi.
class _GroupTestsScreen extends StatelessWidget {
  final TeacherClass group;
  const _GroupTestsScreen({required this.group});

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: group.className,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        child: GroupTestsPanel(
          groupId: group.classId,
          subtitle: group.subjects.isEmpty ? null : group.subjects.map((s) => s.name).join(', '),
        ),
      ),
    );
  }
}
