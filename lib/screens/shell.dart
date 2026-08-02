import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Ko'rilgan tablar tarixi — qurilmaning "orqaga" tugmasi ilovadan chiqarib
  /// yubormasin, avval OLDINGI tabga qaytsin (Android odatiy xatti-harakati).
  final List<int> _history = [0];

  /// Suhbat tabining holatiga murojaat — u tab ICHIDA suhbat ochadi (alohida route
  /// emas), shuning uchun "orqaga" avval shu suhbatni yopishi kerak.
  final _messagesKey = GlobalKey<MessagesScreenState>();

  /// Dashboard'da "orqaga" bosilgan oxirgi vaqt — tasodifan chiqib ketmaslik uchun
  /// ikki marta bosish talab qilinadi.
  DateTime? _exitTapAt;

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const RatingScreen(showBack: false),
    const TestsScreen(),
    MessagesScreen(key: _messagesKey),
    const ProfileScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      // Bir tab tarixda ikki marta turmaydi (tarix cheksiz o'smasin).
      _history.remove(i);
      _history.add(i);
      _index = i;
    });
  }

  /// Qurilmaning "orqaga" tugmasi. Tartib: tab ichidagi holat → oldingi tab →
  /// Dashboard → (ikki marta bosilsa) ilovadan chiqish.
  void _handleBack() {
    if (_messagesKey.currentState?.handleBack() ?? false) return;

    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _index = _history.last;
      });
      return;
    }
    if (_index != 0) {
      // TUZATILDI: avval faqat `_index` o'zgarardi va `_history` desinxronlashib
      // qolardi (keyingi "orqaga" allaqachon ochiq turgan tabga qaytarardi).
      setState(() {
        _index = 0;
        _history
          ..clear()
          ..add(0);
      });
      return;
    }

    final now = DateTime.now();
    final last = _exitTapAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _exitTapAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chiqish uchun yana bir marta bosing'),
        duration: Duration(seconds: 2),
      ),
    );
  }

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
    // canPop: false — "orqaga" ni to'liq o'zimiz boshqaramiz (tab tarixi, tab ichidagi
    // suhbat, chiqishni tasdiqlash). Tab ustiga PUSH qilingan ekranlar alohida route
    // bo'lgani uchun ular avvalgidek odatiy tarzda yopiladi.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          // TUZATILDI (P1-8): `IndexedStack` tabni dispose qilmaydi va uning
          // `Visibility` o'rami `maintainAnimation: true` beradi — ya'ni
          // ko'rinmayotgan tab ham "tirik". Har bir tabni `TickerMode` bilan
          // o'raymiz, shunda faol bo'lmagan tab (masalan chat polleri) o'z
          // taymerini to'xtata oladi.
          child: IndexedStack(
            index: _index,
            children: [
              for (int i = 0; i < _screens.length; i++)
                TickerMode(enabled: _index == i, child: _screens[i]),
            ],
          ),
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
                      child: _TabItem(def: _tabs[i], active: _index == i, onTap: () => _select(i)),
                    ),
                ],
              ),
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
          Text(
            def.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
