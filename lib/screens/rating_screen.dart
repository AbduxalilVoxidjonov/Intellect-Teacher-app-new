import 'package:flutter/material.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// O'z guruhlaridagi o'quvchilar reytingi (ball = jurnal baholari +
/// bajarilgan mezonlar). Web: `rating/TeacherRatingPage.tsx`.
class RatingScreen extends StatefulWidget {
  /// Root-tab sifatida ko'rsatilganda orqaga tugmasi kerak emas.
  final bool showBack;
  const RatingScreen({super.key, this.showBack = true});
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  TeacherRating? _rating;
  bool _loading = true;
  String? _error;
  /// Tanlangan guruh (null = barcha guruhlar).
  String? _group;

  /// Barcha guruh nomlari (o'quvchilar guruhlaridan yig'iladi).
  List<String> _allGroups(List<TeacherRatingRow> rows) {
    final set = <String>{};
    for (final r in rows) {
      for (final g in r.groups.split(',')) {
        final t = g.trim();
        if (t.isNotEmpty) set.add(t);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  bool _inGroup(TeacherRatingRow r, String g) =>
      r.groups.split(',').map((s) => s.trim()).contains(g);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await TeacherApi.rating();
      if (mounted) setState(() => _rating = r);
    } catch (_) {
      if (mounted) setState(() => _error = "Reytingni yuklab bo'lmadi");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _podium = {
    1: [Color(0xFFFBBF24), Color(0xFFD97706)],
    2: [Color(0xFFCBD5E1), Color(0xFF64748B)],
    3: [Color(0xFFFDBA74), Color(0xFFEA580C)],
  };

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final rating = _rating;
    final allRows = rating?.rows ?? const <TeacherRatingRow>[];
    final groups = _allGroups(allRows);
    // Tanlangan guruh bo'yicha filtr (tartib ball bo'yicha saqlanadi).
    final rows = _group == null ? allRows : allRows.where((r) => _inGroup(r, _group!)).toList();
    final top3 = rows.take(3).toList();
    final rest = rows.skip(3).toList();
    final maxBall = rows.isNotEmpty ? rows.first.ball : 0;
    // Ko'rsatiladigan statistika (filtrga qarab).
    final shownStudents = rows.length;
    final shownGroups = _group == null ? rating?.groupsCount ?? groups.length : 1;
    final shownAvg = rows.isEmpty ? 0.0 : rows.fold<int>(0, (a, r) => a + r.ball) / rows.length;

    Widget body;
    if (_loading) {
      body = const Center(child: Loader());
    } else if (_error != null) {
      body = Center(child: EmptyState(icon: Icons.error_outline_rounded, text: _error!));
    } else if (rating == null || allRows.isEmpty) {
      body = const Center(
        child: EmptyState(
          icon: Icons.emoji_events_outlined,
          text: "Reyting uchun ma'lumot yo'q — guruhlaringizda hali jurnal bahosi yoki bajarilgan mezon qayd etilmagan.",
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          SCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.emoji_events_rounded, color: c.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$shownStudents ta o'quvchi · $shownGroups ta guruh",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                          Text(_group ?? rating.fullName,
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _StatBox(label: 'Guruhlar', value: '$shownGroups', color: c.text)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(label: "O'quvchilar", value: '$shownStudents', color: c.text)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatBox(
                            label: "O'rtacha ball", value: shownAvg.toStringAsFixed(1), color: c.accent)),
                  ],
                ),
              ],
            ),
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _groupChip(c, 'Barcha guruhlar', _group == null, () => setState(() => _group = null)),
                  for (final g in groups) ...[
                    const SizedBox(width: 8),
                    _groupChip(c, g, _group == g, () => setState(() => _group = g)),
                  ],
                ],
              ),
            ),
          ],
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(icon: Icons.group_off_outlined, text: "Bu guruhda o'quvchi topilmadi."),
            )
          else ...[
            if (top3.isNotEmpty) ...[
              const SizedBox(height: 14),
              _podiumRow(top3),
            ],
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (var i = 0; i < rest.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _RatingRow(
                  row: rest[i],
                  rank: i + 4,
                  maxBall: maxBall,
                  // Pastga tushgan sari rang kuchi kamayadi (1.0 → 0.35).
                  intensity: rest.length <= 1 ? 1.0 : 0.35 + 0.65 * (1 - i / (rest.length - 1)),
                ),
              ],
            ],
          ],
          const SizedBox(height: 14),
          Center(
            child: Text('Ball = jurnal baholari + bajarilgan mezonlar',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.faint)),
          ),
        ],
      );
    }

    return SubScaffold(title: "O'quvchilar reytingi", showBack: widget.showBack, child: body);
  }

  Widget _groupChip(AppColors c, String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c.accent : c.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : c.text)),
      ),
    );
  }

  /// Podium: 1-o'rin o'rtada (kattaroq), 2-o'rin o'ngda, 3-o'rin chapda.
  Widget _podiumRow(List<TeacherRatingRow> top3) {
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: third == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: _PodiumCard(row: third, rank: 3, gradient: _podium[3]!),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: first == null
              ? const SizedBox()
              : _PodiumCard(row: first, rank: 1, gradient: _podium[1]!, big: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: second == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: _PodiumCard(row: second, rank: 2, gradient: _podium[2]!),
                ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.faint)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final TeacherRatingRow row;
  final int rank;
  final List<Color> gradient;
  final bool big;
  const _PodiumCard({required this.row, required this.rank, required this.gradient, this.big = false});

  String get _initials {
    final parts = row.fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    String f(String s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : f(parts[0]);
    }
    return f(parts[0]) + f(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final accent = gradient.last;
    final avatar = big ? 58.0 : 46.0;
    return Container(
      padding: EdgeInsets.symmetric(vertical: big ? 16 : 12, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: c.isDark ? 0.30 : 0.16), c.surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: big ? 1.6 : 1.1),
        boxShadow: big
            ? [BoxShadow(color: accent.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 6))]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(big ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
              color: accent, size: big ? 24 : 18),
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: avatar,
                height: avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.40), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Text(_initials,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: big ? 20 : 16)),
              ),
              Positioned(
                bottom: -7,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Text('$rank',
                      style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            row.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: big ? 13 : 12, fontWeight: FontWeight.w800, color: c.text, height: 1.2),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: accent.withValues(alpha: c.isDark ? 0.26 : 0.14), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: 13, color: accent),
                const SizedBox(width: 3),
                Text('${row.ball}',
                    style: TextStyle(fontSize: big ? 15 : 13, fontWeight: FontWeight.w800, color: accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final TeacherRatingRow row;
  final int rank;
  final int maxBall;
  /// Rang kuchi: 1.0 = to'yingan (yuqori o'rin), pastga tushgan sari kamayadi.
  final double intensity;
  const _RatingRow({
    required this.row,
    required this.rank,
    required this.maxBall,
    this.intensity = 1.0,
  });

  String get _initials {
    final parts = row.fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    String f(String s) => s.isEmpty ? '' : s.substring(0, 1).toUpperCase();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : f(parts[0]);
    }
    return f(parts[0]) + f(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Bitta rang (teal accent), o'rin pasaygan sari ochlashib boradi.
    final fade = c.isDark ? c.surface : Colors.white;
    final rowColor = Color.lerp(fade, c.accent, intensity)!;
    final onAvatar = rowColor.computeLuminance() > 0.55 ? c.accentD : Colors.white;
    final pct = maxBall > 0 ? (row.ball / maxBall).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [rowColor.withValues(alpha: c.isDark ? 0.22 : 0.14), c.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rowColor.withValues(alpha: 0.55)),
        boxShadow: c.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rowColor,
                      boxShadow: [BoxShadow(color: rowColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Text(_initials,
                        style: TextStyle(color: onAvatar, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.surface,
                        border: Border.all(color: rowColor, width: 2),
                      ),
                      child: Text('$rank',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: c.accentD)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.fullName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                    if (row.groups.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(row.groups, style: TextStyle(fontSize: 11, color: c.muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: rowColor.withValues(alpha: c.isDark ? 0.34 : 0.20),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: c.accentD),
                        const SizedBox(width: 3),
                        Text('${row.ball}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accentD)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("o'rtacha: ${row.average.toStringAsFixed(1)}",
                      style: TextStyle(fontSize: 11, color: c.faint)),
                  if (row.attendance != null)
                    Text('davomat: ${row.attendance!.round()}%',
                        style: TextStyle(fontSize: 11, color: c.faint)),
                ],
              ),
            ],
          ),
          if (maxBall > 0) ...[
            const SizedBox(height: 10),
            ProgressBar(pct, color: rowColor, height: 6),
          ],
        ],
      ),
    );
  }
}
