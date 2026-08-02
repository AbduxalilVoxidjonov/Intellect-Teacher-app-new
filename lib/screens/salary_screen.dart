import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/teacher_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// O'qituvchi maoshi — joriy oy (hisoblandi/berildi/qoldi) + oylar ro'yxati
/// (ushlanma bo'lsa bosib guruh+sanalarni ochish). Web: `salary/SalaryPage.tsx`.
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  SalaryLedger? _ledger;
  bool _loading = true;
  String? _expanded;

  /// P1-13: TARMOQ xatosi "maosh yo'q" DEGANI EMAS — puli bor o'qituvchiga
  /// "hisoblangan oylik mavjud emas" deyish mumkin emas. Shuning uchun xato
  /// haqiqiy bo'sh holatdan alohida saqlanadi.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await TeacherApi.salary();
      if (mounted) {
        setState(() {
          _ledger = l;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is ApiException ? e.message : "Maosh ma'lumotini yuklab bo'lmadi");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  ({String label, Color color, Color bg}) _statusStyle(AppColors c, String status) {
    switch (status) {
      case 'paid':
        return (label: "To'langan", color: c.green, bg: c.greenSoft);
      case 'partial':
        return (label: 'Qisman', color: c.amber, bg: c.amberSoft);
      default:
        return (label: "To'lanmagan", color: c.red, bg: c.redSoft);
    }
  }

  MonthSalary? _findMonth(List<MonthSalary> months, String key) {
    for (final m in months) {
      if (m.month == key) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final ledger = _ledger;
    final now = DateTime.now();
    final curKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    Widget body;
    if (_loading) {
      body = const Center(child: Loader());
    } else if (_error != null && ledger == null) {
      // Xato — bo'sh holat EMAS: sabab ko'rsatiladi va qayta urinish taklif qilinadi.
      body = _refreshable([
        const SizedBox(height: 24),
        EmptyState(icon: Icons.error_outline_rounded, text: _error!),
        Center(
          child: SizedBox(
            width: 180,
            child: SButton('Qayta urinish',
                icon: Icons.refresh_rounded, kind: BtnKind.soft, onTap: _load),
          ),
        ),
      ]);
    } else if (ledger == null || ledger.months.isEmpty) {
      body = _refreshable(const [
        SizedBox(height: 24),
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          text: "Maosh ma'lumoti yo'q — hozircha hisoblangan oylik mavjud emas.",
        ),
      ]);
    } else {
      final cur = _findMonth(ledger.months, curKey);
      final expected = cur?.expected ?? ledger.totalExpected;
      final paid = cur?.paid ?? ledger.totalPaid;
      final remaining = cur?.remaining ?? ledger.remaining;
      final modeSub = ledger.salaryMode == 'percent'
          ? "Yig'ilgan to'lovga asoslangan (${ledger.salaryPercent}%)"
          : "Qat'iy oylik";
      final months = ledger.months.reversed.toList();

      body = RefreshIndicator(
        color: c.accent,
        onRefresh: _load,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        physics: const AlwaysScrollableScrollPhysics(),
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
                      child: Icon(Icons.account_balance_wallet_rounded, color: c.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cur != null ? fmtMonth(curKey) : 'Jami',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                          Text(modeSub, style: TextStyle(fontSize: 12, color: c.muted), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _StatBox(label: 'Hisoblandi', value: fmtMoney(expected), color: c.text)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(label: 'Berildi', value: fmtMoney(paid), color: c.accent)),
                    const SizedBox(width: 8),
                    Expanded(child: _StatBox(label: 'Qoldi', value: fmtMoney(remaining), color: c.text)),
                  ],
                ),
                if (cur != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jami qoldiq', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.accentD)),
                        Text(fmtMoney(ledger.remaining),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accentD)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (ledger.journalLinked ?? false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.amberSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Maosh jurnal bo\'yicha hisoblanadi: jurnalda "o\'tildi" deb belgilanmagan dars '
                      "o'tilmagan hisoblanib, oylikdan ushlanadi. Tafsiloti uchun oyni bosing.",
                      style: TextStyle(fontSize: 12, color: c.text, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SectionTitle('Oylar'),
          SCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < months.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.border),
                  _MonthRow(
                    month: months[i],
                    style: _statusStyle(c, months[i].status),
                    expanded: _expanded == months[i].month,
                    onTap: (months[i].deduction ?? 0) > 0
                        ? () => setState(() => _expanded = _expanded == months[i].month ? null : months[i].month)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      );
    }

    return SubScaffold(title: 'Maosh', child: body);
  }

  /// Bo'sh/xato holatlar ham pastga tortib yangilanadi (`RefreshIndicator`
  /// scroll qilinadigan bola talab qiladi).
  Widget _refreshable(List<Widget> children) {
    final c = AppTheme.of(context);
    return RefreshIndicator(
      color: c.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
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

class _MonthRow extends StatelessWidget {
  final MonthSalary month;
  final ({String label, Color color, Color bg}) style;
  final bool expanded;
  final VoidCallback? onTap;
  const _MonthRow({required this.month, required this.style, required this.expanded, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final missed = month.missedLessons ?? 0;
    final deduction = month.deduction ?? 0;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(fmtMonth(month.month),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                          if (onTap != null) ...[
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: c.faint),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 12, color: c.muted),
                          children: [
                            const TextSpan(text: 'Hisoblandi: '),
                            TextSpan(text: fmtMoney(month.expected), style: TextStyle(color: c.text)),
                            const TextSpan(text: '  ·  Berildi: '),
                            TextSpan(text: fmtMoney(month.paid), style: TextStyle(color: c.accent)),
                          ],
                        ),
                      ),
                      if (deduction > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Ushlandi: −${fmtMoney(deduction)}  ($missed ta dars belgilanmagan)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.red),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SChip(style.label, color: style.color, bg: style.bg),
                    const SizedBox(height: 6),
                    Text('Qoldi: ${fmtMoney(month.remaining)}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.faint)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            color: c.surface2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belgilanmagan darslar — hisoblangan: ${fmtMoney(month.baseExpected ?? 0)}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.faint)),
                const SizedBox(height: 8),
                for (final l in (month.lessons ?? const <SalaryLessonStat>[]))
                  if (l.missed > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(l.groupName,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
                              ),
                              Text('−${fmtMoney(l.deduction)}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.red)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('${l.conducted}/${l.planned} dars belgilangan',
                              style: TextStyle(fontSize: 11, color: c.muted)),
                          if (l.missedDates.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final d in l.missedDates)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(6)),
                                    child: Text(d.length > 5 ? d.substring(5) : d,
                                        style: TextStyle(fontSize: 11, color: c.red)),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
