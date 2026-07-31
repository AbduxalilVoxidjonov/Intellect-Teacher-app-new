import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/teacher_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../group_detail_screen.dart';

/// Bosh sahifa (TAB) — web `TeacherDashboard.tsx` bilan mos: salomlashuv +
/// bildirishnomalar, tezkor statistika (guruhlar/fanlar), guruhlar ro'yxati.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  bool _error = false;
  TeacherProfile? _profile;
  List<TeacherClass> _classes = [];
  PortalMeta? _meta;
  NotificationsResponse? _notifs;
  SalaryLedger? _salary;
  TeacherRating? _rating;
  TeacherSchoolInfo? _school;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final profile = await TeacherApi.profile();
      final classes = await TeacherApi.myClasses();
      final meta = await TeacherApi.meta();
      final notifs = await TeacherApi.notifications();
      final salary = await TeacherApi.salary().catchError((_) => null);
      final rating = await TeacherApi.rating().catchError((_) => null);
      TeacherSchoolInfo? school;
      try {
        school = await TeacherApi.school();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _classes = classes;
        _meta = meta;
        _notifs = notifs;
        _salary = salary;
        _rating = rating;
        _school = school;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    if (_notifs != null && _notifs!.unread > 0) {
      TeacherApi.markNotificationsRead().catchError((_) {});
      setState(() {
        _notifs = NotificationsResponse(
          unread: 0,
          items: _notifs!.items
              .map((i) => AppNotification(
                    id: i.id,
                    title: i.title,
                    body: i.body,
                    type: i.type,
                    createdAt: i.createdAt,
                    read: true,
                    confirmed: i.confirmed,
                  ))
              .toList(),
        );
      });
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(items: _notifs?.items ?? const []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final session = context.watch<Session>();
    final fullName = (_profile?.fullName.isNotEmpty == true) ? _profile!.fullName : session.fullName;
    final parts = fullName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    // Salomlashuvda "Familiya Ism" (birinchi ikki so'z) ko'rsatiladi.
    final firstName = parts.length >= 2
        ? '${parts[0]} ${parts[1]}'
        : (parts.isNotEmpty ? parts.first : 'ustoz');
    final activeStudents = _rating?.studentsCount ?? 0;
    final salaryExpected = _currentSalaryExpected();

    return Column(
      children: [
        _header(c, firstName, fullName),
        Expanded(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: _load,
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 220), Center(child: Loader())],
                  )
                : _error
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          EmptyState(
                            icon: Icons.wifi_off_rounded,
                            text: "Ma'lumotlarni yuklab bo'lmadi. Pastga torting va qayta urining.",
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _statCard(c, Icons.school_rounded, c.accent, c.accentSoft,
                                    '${_classes.length}', 'Guruhlar',
                                    sub: "$activeStudents faol o'quvchi"),
                                const SizedBox(width: 10),
                                _statCard(c, Icons.account_balance_wallet_rounded, const Color(0xFF0284C7),
                                    const Color(0xFFE0F2FE),
                                    salaryExpected == null ? '—' : fmtMoney(salaryExpected), 'Maosh'),
                              ],
                            ),
                          ),
                          if (_telegramUrl() != null) ...[
                            const SizedBox(height: 12),
                            _telegramCard(c),
                          ],
                          const SizedBox(height: 18),
                          SectionTitle('Mening guruhlarim'),
                          if (_classes.isEmpty)
                            const EmptyState(
                              text: "Sizga biriktirilgan guruh yo'q. Markaz ma'muriyatiga murojaat qiling.",
                            )
                          else
                            Column(
                              children: [
                                for (final g in _classes) ...[
                                  _groupTile(context, c, g),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _header(AppColors c, String firstName, String fullName) {
    final dateLine = fmtDate(DateTime.now().toIso8601String(), weekday: true);
    final weekLabel = (_meta != null && _meta!.currentWeek > 0) ? '${_meta!.currentWeek}-hafta' : '';
    final unread = _notifs?.unread ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekLabel.isEmpty ? dateLine : '$dateLine  •  $weekLabel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                      letterSpacing: -0.3,
                    ),
                    children: [
                      const TextSpan(text: 'Assalomu alaykum, '),
                      TextSpan(text: firstName, style: TextStyle(color: c.accent)),
                      const TextSpan(text: ' \u{1F44B}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openNotifications,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(12)),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_rounded, color: c.text, size: 20),
                  if (unread > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.red,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.surface, width: 2),
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Avatar(name: fullName.isEmpty ? '?' : fullName, size: 40),
        ],
      ),
    );
  }

  Widget _statCard(AppColors c, IconData icon, Color iconColor, Color iconBg, String value, String label,
      {String? sub}) {
    return Expanded(
      child: SCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.accent)),
              ),
          ],
        ),
      ),
    );
  }

  /// Joriy oyning hisoblangan maoshi (topilmasa jami — bo'lmasa null).
  double? _currentSalaryExpected() {
    final l = _salary;
    if (l == null || l.months.isEmpty) return null;
    final now = DateTime.now();
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    for (final m in l.months) {
      if (m.month == key) return m.expected;
    }
    return l.totalExpected;
  }

  /// Markaz Telegram kanali havolasi (bo'lmasa null).
  String? _telegramUrl() {
    final ch = _school?.telegramChannel.trim() ?? '';
    if (ch.isEmpty) return null;
    if (ch.startsWith('http')) return ch;
    final handle = ch.replaceFirst(RegExp(r'^@'), '').replaceFirst(RegExp(r'^t\.me/'), '');
    return 'https://t.me/$handle';
  }

  Future<void> _openTelegram() async {
    final url = _telegramUrl();
    if (url == null) return;
    final uri = Uri.parse(url);
    try {
      // Avval Telegram ilovasida/tashqi ilovada ochishga urinamiz,
      // bo'lmasa brauzerda (platformDefault) ochamiz.
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }

  Widget _telegramCard(AppColors c) {
    final ch = _school?.telegramChannel.trim() ?? '';
    return SCard(
      padding: const EdgeInsets.all(14),
      onTap: _openTelegram,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bizning telegram kanal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  ch.isEmpty ? "Markaz e'lonlari kanaliga o'tish" : ch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, color: c.faint, size: 20),
        ],
      ),
    );
  }

  Widget _groupTile(BuildContext context, AppColors c, TeacherClass g) {
    return SCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.classId, groupName: g.className)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent, c.accentD], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _groupInitials(g.className),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text),
                ),
                const SizedBox(height: 6),
                g.subjects.isEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 14, color: c.faint),
                          const SizedBox(width: 4),
                          Text('Fan biriktirilmagan', style: TextStyle(fontSize: 12, color: c.faint)),
                        ],
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: g.subjects.map((s) => SChip(s.name, color: subjectColor(s.name))).toList(),
                      ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.faint),
        ],
      ),
    );
  }
}

String _groupInitials(String name) {
  final cleaned = name.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.isEmpty) return '?';
  return cleaned.substring(0, cleaned.length < 3 ? cleaned.length : 3).toUpperCase();
}

/// Bildirishnomalar pastki paneli (bottom sheet) — o'z holatini o'zi boshqaradi.
class _NotificationsSheet extends StatefulWidget {
  final List<AppNotification> items;
  const _NotificationsSheet({required this.items});

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  late List<AppNotification> _items = List.of(widget.items);

  Future<void> _confirm(String id) async {
    try {
      await TeacherApi.confirmNotification(id);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((i) => i.id == id
              ? AppNotification(
                  id: i.id,
                  title: i.title,
                  body: i.body,
                  type: i.type,
                  createdAt: i.createdAt,
                  read: i.read,
                  confirmed: true,
                )
              : i)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
            ),
            Row(
              children: [
                Expanded(
                  child: Text('Bildirishnomalar',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: c.text),
                ),
              ],
            ),
            Flexible(
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        "Bildirishnoma yo'q. Yangi e'lonlar shu yerda ko'rinadi.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = _items[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(11)),
                                child: Icon(Icons.notifications_rounded, size: 18, color: c.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                                    if (n.body.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(n.body, style: TextStyle(fontSize: 13, color: c.muted)),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(fmtDate(n.createdAt), style: TextStyle(fontSize: 11, color: c.faint)),
                                    ),
                                    if (n.type == 'announcement')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: n.confirmed
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle_rounded, size: 14, color: c.green),
                                                  const SizedBox(width: 4),
                                                  Text('Tasdiqlandi',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.green)),
                                                ],
                                              )
                                            : SButton('Tasdiqlash', kind: BtnKind.soft, onTap: () => _confirm(n.id)),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
