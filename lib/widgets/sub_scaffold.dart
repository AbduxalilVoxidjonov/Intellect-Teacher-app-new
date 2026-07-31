import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sub-screen (profil menyusidan ochiladigan) uchun umumiy qobiq:
/// tepada orqaga tugmasi + sarlavha, ostida kontent. Barcha ichki ekranlar shuni ishlatadi.
class SubScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  /// Kontentni to'g'ridan-to'g'ri (scroll'siz) berish uchun.
  final bool scrollable;
  /// Orqaga tugmasini ko'rsatish (root-tab sifatida ishlatilganda false qilinadi).
  final bool showBack;
  const SubScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.scrollable = false,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  if (showBack) ...[
                    _IconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            Expanded(
              child: scrollable ? SingleChildScrollView(child: child) : child,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: c.text)),
      ),
    );
  }
}
