import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tabs/dashboard_screen.dart';
import 'rating_screen.dart';
import 'tests_screen.dart';
import 'tabs/messages_screen.dart';
import 'tabs/profile_screen.dart';

/// Asosiy qobiq — pastki 5-tab navigatsiya (web `TeacherMobileLayout`ga mos, teal).
///
/// DIQQAT: «Jurnal» tabi ATAYLAB olib tashlangan — jurnalga Dashboard'dagi guruh
/// kartasini bosib kiriladi (guruh sahifasi = jurnal + davomat + baholash + reyting +
/// imtihonlar). Uning o'rniga «Testlar» bo'limi qo'yilgan.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    RatingScreen(showBack: false),
    TestsScreen(),
    MessagesScreen(),
    ProfileScreen(),
  ];

  static const _tabs = [
    _TabDef(Icons.home_rounded, Icons.home_outlined, 'Dashboard'),
    _TabDef(Icons.emoji_events_rounded, Icons.emoji_events_outlined, 'Reyting'),
    _TabDef(Icons.assignment_turned_in_rounded, Icons.assignment_turned_in_outlined, 'Testlar'),
    _TabDef(Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Suhbat'),
    _TabDef(Icons.person_rounded, Icons.person_outline, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      def: _tabs[i],
                      active: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData active;
  final IconData inactive;
  final String label;
  const _TabDef(this.active, this.inactive, this.label);
}

class _TabItem extends StatelessWidget {
  final _TabDef def;
  final bool active;
  final VoidCallback onTap;
  const _TabItem({required this.def, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final color = active ? c.accent : c.faint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? c.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(active ? def.active : def.inactive, size: 22, color: color),
          ),
          const SizedBox(height: 2),
          Text(def.label,
              style: TextStyle(fontSize: 10.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
