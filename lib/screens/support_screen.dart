import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Support — bo'sh vaqt/bron. Web'da to'liq boshqaruv (slot qo'shish/o'chirish,
/// darsni yopish) mavjud (`support/SupportPage.tsx`); mobilda hozircha sodda
/// ma'lumot kartasi — to'liq boshqaruv veb-panelda qoladi.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'Support',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.calendar_month_rounded, color: c.accentD, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Support — bo'sh vaqt va bronlar",
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: c.text)),
                        const SizedBox(height: 4),
                        Text(
                          "Siz bo'sh vaqt bloklarini qo'shasiz, o'quvchilar shu vaqtga bron qiladi va dars "
                          "o'tilgach mavzu+izoh bilan yopiladi. To'liq boshqaruv hozircha veb-panelda mavjud.",
                          style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: EmptyState(
                icon: Icons.event_available_outlined,
                text: "Bu ekran hali ishlab chiqilmoqda.\nSupport bronlarini veb-panelda ko'rishingiz mumkin.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
