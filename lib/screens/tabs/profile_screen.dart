import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/teacher_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../account_screen.dart';
import '../feedback_screen.dart';
import '../salary_screen.dart';
import '../support_screen.dart';

/// Profil (TAB) — web `TeacherProfilePage.tsx` bilan mos: profil kartasi,
/// bo'limlar menyusi, sozlamalar (tungi rejim), chiqish.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  TeacherProfile? _profile;
  TeacherSchoolInfo? _school;
  /// Profil kartasida ko'rsatiladigan guruhlar (fanlar o'rniga).
  List<TeacherClass> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await TeacherApi.profile();
      TeacherSchoolInfo? school;
      try {
        school = await TeacherApi.school();
      } catch (_) {
        school = null;
      }
      // Guruhlar profil kartasida ko'rsatiladi — yuklanmasa karta baribir chiqadi.
      List<TeacherClass> classes = const [];
      try {
        classes = await TeacherApi.myClasses();
      } catch (_) {
        classes = const [];
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _school = school;
        _classes = classes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiqish'),
        content: const Text('Hisobdan chiqishni tasdiqlaysizmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Bekor qilish')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Chiqish')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<Session>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final session = context.watch<Session>();
    final fullName = (_profile?.fullName.isNotEmpty == true) ? _profile!.fullName : session.fullName;
    final subjectsLabel =
        (_profile?.subjects.isNotEmpty == true) ? _profile!.subjects.map((s) => s.name).join(', ') : '—';
    final isSupport = _profile?.isSupport == true;

    final menu = <_MenuItem>[
      // «Baholash» olib tashlandi — baholash guruh (jurnal) sahifasidagi «Baholash»
      // tabida bajariladi. DIQQAT: bu ikkisi turli backend bo'limlari edi — profildagisi
      // /teacher/evaluation (baholash turlari bo'yicha 1–5 baho), jurnaldagisi
      // /teacher/grading (mezonlar bo'yicha bajardi/bajarmadi). API metodlari
      // (TeacherApi.evalTypes / evalBoard / setEvalGrade) qaytarish uchun qoldirildi.
      // «Testlar» bo'limi pastki navigatsiyaga ko'chirildi — menyuda takrorlanmaydi.
      _MenuItem('Maosh', 'Oylik hisob va tarix', Icons.account_balance_wallet_rounded, const Color(0xFF7C3AED),
          () => _open(const SalaryScreen())),
      // «O'quv dasturi» bo'limi HOZIRCHA olib tashlandi (keyinchalik qaytariladi).
      // Backend chaqiruvlari (TeacherApi.groupCurriculum / setGroupCover /
      // changeGroupRevision) ATAYLAB qoldirilgan — qaytarish oson bo'lsin.
      if (isSupport)
        _MenuItem('Support', "Bo'sh vaqt va bron darslari", Icons.support_agent_rounded, const Color(0xFF1F1F94),
            () => _open(const SupportScreen())),
      _MenuItem('Taklif va shikoyat', 'Adminga xabar yuborish', Icons.chat_bubble_outline_rounded,
          const Color(0xFF1F1F94), () => _open(const FeedbackScreen())),
      _MenuItem('Akkaunt', 'Profil va xavfsizlik', Icons.lock_outline_rounded, const Color(0xFF64748B),
          () => _open(const AccountScreen())),
    ];

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: _load,
            child: _loading
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [SizedBox(height: 220), Center(child: Loader())],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _profileCard(c, fullName, subjectsLabel),
                      const SizedBox(height: 18),
                      SectionTitle("Bo'limlar"),
                      _menuCard(c, menu),
                      const SizedBox(height: 18),
                      SectionTitle('Sozlamalar'),
                      _settingsCard(c, session),
                      const SizedBox(height: 20),
                      SButton('Chiqish', icon: Icons.logout_rounded, kind: BtnKind.danger, onTap: _confirmLogout),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _profileCard(AppColors c, String fullName, String subjectsLabel) {
    const avatarSize = 78.0;
    const bannerHeight = 56.0;
    return SCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                height: bannerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.accent, c.accentD], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),
              const SizedBox(height: avatarSize / 2 + 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Column(
                  children: [
                    Text(
                      fullName.isEmpty ? "O'qituvchi" : fullName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text),
                    ),
                    if (_profile?.email.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(_profile!.email, style: TextStyle(fontSize: 12, color: c.muted)),
                    ],
                    const SizedBox(height: 10),
                    SChip("O'qituvchi", color: c.accentD, bg: c.accentSoft),
                    const SizedBox(height: 16),
                    // Fanlar o'rniga GURUHLAR — har biri tag-ma-tag (alohida qatorda).
                    _groupsRow(c),
                    if (_school != null && _school!.name.isNotEmpty)
                      _infoRow(c, Icons.apartment_rounded, 'Markaz', _school!.name),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: bannerHeight - avatarSize / 2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.surface, width: 4)),
                child: Avatar(name: fullName.isEmpty ? 'O' : fullName, size: avatarSize),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// O'qituvchi guruhlari — nomlari tag-ma-tag (har biri alohida qatorda).
  /// Fanlar ATAYLAB ko'rsatilmaydi (guruh nomi yetarli).
  Widget _groupsRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.groups_rounded, size: 17, color: c.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guruhlar', style: TextStyle(fontSize: 11, color: c.muted)),
                if (_classes.isEmpty)
                  Text(
                    _loading ? '—' : "Guruh biriktirilmagan",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.faint),
                  )
                else
                  for (final g in _classes)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        g.className,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text, height: 1.35),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(AppColors c, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: c.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(AppColors c, List<_MenuItem> menu) {
    return SCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < menu.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i < menu.length - 1 ? Border(bottom: BorderSide(color: c.border)) : null,
              ),
              child: InkWell(
                onTap: menu[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: menu[i].color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(menu[i].icon, size: 18, color: menu[i].color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(menu[i].label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                            Text(menu[i].sub, style: TextStyle(fontSize: 11, color: c.muted)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.faint),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingsCard(AppColors c, Session session) {
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.dark_mode_rounded, size: 18, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tungi rejim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                Text(session.isDark ? 'Yoqilgan' : "O'chirilgan", style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          Switch(
            value: session.isDark,
            activeThumbColor: c.accent,
            onChanged: (v) => session.setDark(v),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuItem(this.label, this.sub, this.icon, this.color, this.onTap);
}
