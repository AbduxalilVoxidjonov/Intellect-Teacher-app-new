import 'package:flutter/material.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// Guruh sahifasidagi "O'quv dasturi (darsda o'tilgan)" bo'limi.
///
/// Web `TeacherGroupDetailPage.tsx` ichidagi `CurriculumSection` + `ForecastTile`
/// komponentlari va ular bilan ishlaydigan `toggleCover` / `changeRevision` /
/// `nextItemId` mantiqlarining to'liq ko'chirmasi.
///
/// DIQQAT: bu widget O'ZI VERTIKAL SCROLL QILMAYDI — chaqiruvchi sahifa
/// `SingleChildScrollView` beradi. Shu sababli ichida `Expanded` yoki cheksiz
/// `ListView` yo'q, hamma joyda `Column(mainAxisSize: min)` ishlatilgan.
class GroupCurriculumSection extends StatefulWidget {
  final String groupId;
  const GroupCurriculumSection({super.key, required this.groupId});

  @override
  State<GroupCurriculumSection> createState() => _GroupCurriculumSectionState();
}

class _GroupCurriculumSectionState extends State<GroupCurriculumSection> {
  /// Karta yig'ilgan/yoyilgan holati — web bilan bir xil, boshlanishida YOPIQ.
  bool _open = false;
  bool _loading = true;
  GroupCurriculum? _curr;

  /// Modul/mavzu id'lari — yoyilganlar to'plami (web `currExpanded`). Default — yopiq.
  final Set<String> _expanded = <String>{};

  /// Takrorlash darsi saqlanayotgan payt tugmalarni bloklash uchun (web `revSaving`).
  bool _revSaving = false;

  /// Optimistik belgilash ustqurmasi: itemId → covered.
  /// Modellar o'zgarmas (`final`) bo'lgani uchun web'dagidek `setCurr({...curr})`
  /// qilib bo'lmaydi — shuning uchun serverdan javob kelgunga qadar UI shu
  /// xaritadan o'qiydi. Muvaffaqiyatli refetchdan keyin tozalanadi, xatoda esa
  /// tegishli kalit olib tashlanadi (avvalgi holat qaytadi).
  final Map<String, bool> _coverOverride = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await TeacherApi.groupCurriculum(widget.groupId);
      if (!mounted) return;
      setState(() {
        _curr = c;
        // Server holati keldi — optimistik ustqurma endi kerak emas.
        _coverOverride.clear();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Bandning KO'RINADIGAN holati: optimistik ustqurma bo'lsa u, aks holda server holati.
  bool _covered(GroupCurriculumItem it) => _coverOverride[it.id] ?? it.covered;

  /// O'tilganlar soni — optimistik o'zgarishlarni hisobga olib.
  /// (Server `coveredCount`i refetchdan keyin keladi, shu sababli oradagi
  /// farqni o'zimiz qo'shib/ayirib turamiz — progress bar sakramasligi uchun.)
  int get _coveredCount {
    final k = _curr;
    if (k == null) return 0;
    if (_coverOverride.isEmpty) return k.coveredCount;
    var delta = 0;
    for (final lv in k.levels) {
      for (final tp in lv.topics) {
        for (final it in tp.items) {
          final o = _coverOverride[it.id];
          if (o != null && o != it.covered) delta += o ? 1 : -1;
        }
      }
    }
    return (k.coveredCount + delta).clamp(0, k.totalItems);
  }

  /// Birinchi o'tilmagan band — "keyingi" maslahati uchun (web `nextItemId`).
  String? get _nextItemId {
    final k = _curr;
    if (k == null) return null;
    for (final lv in k.levels) {
      for (final tp in lv.topics) {
        for (final it in tp.items) {
          if (!_covered(it)) return it.id;
        }
      }
    }
    return null;
  }

  void _toggleNode(String nodeId) {
    setState(() {
      if (!_expanded.remove(nodeId)) _expanded.add(nodeId);
    });
  }

  /// Band belgilash — optimistik, so'ng refetch (prognoz aniq qolishi uchun).
  Future<void> _toggleCover(String itemId, bool covered) async {
    if (_curr == null) return;
    setState(() => _coverOverride[itemId] = covered);
    try {
      await TeacherApi.setGroupCover(widget.groupId, itemId, covered);
      await _load();
    } catch (_) {
      if (!mounted) return;
      // Xato — avvalgi holatni qaytaramiz.
      setState(() => _coverOverride.remove(itemId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saqlab bo'lmadi")),
      );
    }
  }

  /// Takrorlash darsi qo'shish (+1) / olib tashlash (−1).
  Future<void> _changeRevision(int delta) async {
    if (_curr == null || _revSaving) return;
    setState(() => _revSaving = true);
    try {
      await TeacherApi.changeGroupRevision(widget.groupId, delta);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saqlab bo'lmadi")),
      );
    } finally {
      if (mounted) setState(() => _revSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final k = _curr;
    const radius = AppSizes.cardLg;

    return SCard(
      padding: EdgeInsets.zero,
      radius: radius,
      child: ClipRRect(
        // Ichki qatorlarning o'z foni karta burchaklaridan chiqib ketmasligi uchun.
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Sarlavha (bosilganda yoyiladi/yig'iladi) ----------
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.checklist_rtl, size: 20, color: c.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "O'quv dasturi (darsda o'tilgan)",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (k != null && k.totalItems > 0) ...[
                      Text(
                        '$_coveredCount/${k.totalItems}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: c.accentD,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 20,
                      color: c.faint,
                    ),
                  ],
                ),
              ),
            ),

            // ---------- Yoyilgan tarkib ----------
            if (_open) ...[
              Divider(height: 1, thickness: 1, color: c.border),
              if (_loading && k == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Loader(label: "O'quv dasturi yuklanmoqda..."),
                )
              else if (k == null || k.totalItems == 0 || k.levels.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 34),
                  child: Text(
                    "Bu guruh kursida o'quv dasturi yo'q.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.faint),
                  ),
                )
              else ...[
                _forecast(context, k),
                Divider(height: 1, thickness: 1, color: c.border),
                // Daraxt: modullar (`levels`) → mavzular → bandlar.
                for (final level in k.levels)
                  _ModuleRow(
                    level: level,
                    open: _expanded.contains(level.id),
                    expanded: _expanded,
                    nextItemId: _nextItemId,
                    coveredOf: _covered,
                    onToggleNode: _toggleNode,
                    onToggleCover: _toggleCover,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Progress + 4 ta prognoz plitkasi + takrorlash darsi tugmalari.
  Widget _forecast(BuildContext context, GroupCurriculum k) {
    final c = AppTheme.of(context);
    final done = _coveredCount;
    final pct = k.totalItems > 0 ? done / k.totalItems : 0.0;
    final pctInt = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bajarildi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted),
                ),
              ),
              Text(
                '$done/${k.totalItems} · $pctInt%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.accentD),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(pct, color: c.accent, height: 10),
          const SizedBox(height: 14),

          // 2×2 prognoz plitkalari (web `grid-cols-2`).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ForecastTile(
                    icon: Icons.check_circle_outline,
                    label: "O'TILGAN",
                    value: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$done'),
                          TextSpan(text: '/${k.totalItems}', style: TextStyle(color: c.faint)),
                        ],
                      ),
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ForecastTile(
                    icon: Icons.repeat,
                    label: 'TAKRORLASH',
                    value: Text(
                      '${k.revisionLessons}',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ForecastTile(
                    icon: Icons.flag_outlined,
                    label: 'QOLGAN',
                    value: Text(
                      '${k.remainingItems} band',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ForecastTile(
                    icon: Icons.event_available_outlined,
                    label: 'TUGATISHGA',
                    value: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '~${k.estLessonsLeft} dars',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                        ),
                        if (k.estFinishDate != null && k.estFinishDate!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '≈ ${fmtDate(k.estFinishDate)} da',
                              style: TextStyle(fontSize: 11.5, color: c.faint),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Takrorlash darsi: qo'shish / olib tashlash.
          Row(
            children: [
              _PillBtn(
                icon: Icons.add,
                label: 'Takrorlash darsi',
                bg: c.accentSoft,
                fg: c.accent,
                onTap: _revSaving ? null : () => _changeRevision(1),
              ),
              const SizedBox(width: 8),
              _PillBtn(
                icon: Icons.remove,
                bg: c.surface3,
                fg: c.muted,
                tooltip: 'Oxirgi takrorlash darsini olib tashlash',
                // Manfiy qiymat bo'lmasligi uchun 0'da o'chirilgan (web bilan bir xil).
                onTap: (_revSaving || k.revisionLessons <= 0) ? null : () => _changeRevision(-1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prognoz plitkasi (web `ForecastTile`).
class _ForecastTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;
  const _ForecastTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: c.faint),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: c.faint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
  }
}

/// Kichik "pill" tugma (matnsiz ham bo'lishi mumkin — kvadrat "−" tugmasi).
class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color bg;
  final Color fg;
  final String? tooltip;
  final VoidCallback? onTap;
  const _PillBtn({
    required this.icon,
    this.label,
    required this.bg,
    required this.fg,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final btn = Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: label == null ? c.border : Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: fg),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Modul qatori (web `module` — ilova modelida `GroupCurriculumLevel`).
class _ModuleRow extends StatelessWidget {
  final GroupCurriculumLevel level;
  final bool open;
  final Set<String> expanded;
  final String? nextItemId;
  final bool Function(GroupCurriculumItem) coveredOf;
  final void Function(String nodeId) onToggleNode;
  final Future<void> Function(String itemId, bool covered) onToggleCover;
  const _ModuleRow({
    required this.level,
    required this.open,
    required this.expanded,
    required this.nextItemId,
    required this.coveredOf,
    required this.onToggleNode,
    required this.onToggleCover,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Modul sanog'i = uning barcha mavzulari bandlari yig'indisi.
    final items = [for (final tp in level.topics) ...tp.items];
    final covered = items.where(coveredOf).length;
    final complete = items.isNotEmpty && covered == items.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: c.surface2,
          child: InkWell(
            onTap: () => onToggleNode(level.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 19,
                    color: c.faint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(covered: covered, total: items.length, complete: complete),
                ],
              ),
            ),
          ),
        ),
        if (open)
          for (final topic in level.topics)
            _TopicRow(
              topic: topic,
              open: expanded.contains(topic.id),
              nextItemId: nextItemId,
              coveredOf: coveredOf,
              onToggleNode: onToggleNode,
              onToggleCover: onToggleCover,
            ),
        Divider(height: 1, thickness: 1, color: c.border),
      ],
    );
  }
}

/// Mavzu qatori.
class _TopicRow extends StatelessWidget {
  final GroupCurriculumTopic topic;
  final bool open;
  final String? nextItemId;
  final bool Function(GroupCurriculumItem) coveredOf;
  final void Function(String nodeId) onToggleNode;
  final Future<void> Function(String itemId, bool covered) onToggleCover;
  const _TopicRow({
    required this.topic,
    required this.open,
    required this.nextItemId,
    required this.coveredOf,
    required this.onToggleNode,
    required this.onToggleCover,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final covered = topic.items.where(coveredOf).length;
    final complete = topic.items.isNotEmpty && covered == topic.items.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, thickness: 1, color: c.border),
        Material(
          color: c.surface,
          child: InkWell(
            onTap: () => onToggleNode(topic.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 19,
                    color: c.faint,
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(Icons.menu_book_outlined, size: 16, color: c.accent),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountBadge(covered: covered, total: topic.items.length, complete: complete),
                ],
              ),
            ),
          ),
        ),
        if (open)
          Container(
            color: c.surface2,
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (topic.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 2),
                    child: Text(topic.note, style: TextStyle(fontSize: 11.5, color: c.faint)),
                  ),
                if (topic.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    child: Text("Topshiriq yo'q.", style: TextStyle(fontSize: 11.5, color: c.faint)),
                  )
                else
                  for (final item in topic.items)
                    _ItemRow(
                      item: item,
                      covered: coveredOf(item),
                      isNext: item.id == nextItemId,
                      onToggleCover: onToggleCover,
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `covered/total` sanog'i — to'liq bajarilganda yashil.
class _CountBadge extends StatelessWidget {
  final int covered;
  final int total;
  final bool complete;
  const _CountBadge({required this.covered, required this.total, required this.complete});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: complete ? c.greenSoft : c.surface3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$covered/$total',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: complete ? c.green : c.muted,
        ),
      ),
    );
  }
}

/// Band (item) qatori — checkbox ko'rinishida.
class _ItemRow extends StatelessWidget {
  final GroupCurriculumItem item;
  final bool covered;
  final bool isNext;
  final Future<void> Function(String itemId, bool covered) onToggleCover;
  const _ItemRow({
    required this.item,
    required this.covered,
    required this.isNext,
    required this.onToggleCover,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Fon: o'tilgan — och yashil, keyingi band — accent soft, aks holda shaffof.
    final bg = covered
        ? c.greenSoft.withValues(alpha: c.isDark ? 0.45 : 0.55)
        : isNext
            ? c.accentSoft
            : Colors.transparent;

    return Material(
      color: bg,
      child: InkWell(
        onTap: () => onToggleCover(item.id, !covered),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                covered ? Icons.check_box : Icons.check_box_outline_blank,
                size: 19,
                color: covered ? c.accentD : c.faint,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 13,
                              color: covered ? c.faint : c.text,
                              decoration: covered ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        // "keyingi" yorlig'i — birinchi o'tilmagan band (web `nextItemId`).
                        if (isNext) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'keyingi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: c.accentD,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.note, style: TextStyle(fontSize: 11, color: c.faint)),
                      ),
                  ],
                ),
              ),
              // O'tilgan sanasi.
              if (covered && item.coveredDate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    fmtDate(item.coveredDate),
                    style: TextStyle(fontSize: 10.5, color: c.faint),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
