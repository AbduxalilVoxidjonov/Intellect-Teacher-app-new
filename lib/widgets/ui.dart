import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Umumiy UI komponentlari — web `.student-app` uslubiga mos (card 20px radius, soft shadow, ...).

/// Karta konteyner (`.card`).
class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  const SCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppSizes.card,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
        boxShadow: c.shadow,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return _Press(onTap: onTap!, child: box);
  }
}

/// Bosilganda kichrayadigan (`.press`) o'ram.
class _Press extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Press({required this.child, required this.onTap});
  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  double _s = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _s = 0.975),
      onTapUp: (_) => setState(() => _s = 1),
      onTapCancel: () => setState(() => _s = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

/// Ekran sarlavhasi (`.hd .hd-big`).
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? subtitle;
  const ScreenHeader(this.title, {super.key, this.trailing, this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                if (subtitle != null) subtitle!,
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bo'lim sarlavhasi (`.sh-title`).
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rangli chip (`.chip`).
class SChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? bg;
  const SChip(this.text, {super.key, required this.color, this.bg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// Progress bar (`.progress`).
class ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  const ProgressBar(this.value, {super.key, this.color, this.height = 8});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: c.surface3,
        valueColor: AlwaysStoppedAnimation(color ?? c.accent),
      ),
    );
  }
}

/// Doiraviy progress ring (markazda ixtiyoriy widget).
class Ring extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? center;
  const Ring({
    super.key,
    required this.value,
    this.max = 100,
    this.size = 72,
    this.stroke = 7,
    this.color,
    this.center,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(pct, stroke, color ?? c.accent, c.surface3),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.pct, this.stroke, this.color, this.track);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width - stroke) / 2;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, r, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

/// Avatar (gradient doira, bosh harflar yoki rasm).
class Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  const Avatar({super.key, required this.name, this.imageUrl, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [c.accent, const Color(0xFF5340C4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: (imageUrl != null && imageUrl!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      child: (imageUrl == null || imageUrl!.isEmpty)
          ? Text(initials(name),
              style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w700))
          : null,
    );
  }
}

/// Bo'sh holat (`.empty`).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.text});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: c.faint, size: 30),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Yuklanish (`.spin`).
class Loader extends StatelessWidget {
  final String? label;
  const Loader({super.key, this.label});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: TextStyle(color: c.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Asosiy tugma (`.btn-primary`) va variantlari.
enum BtnKind { primary, soft, ghost, danger, outline }

class SButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool loading;
  final bool large;
  /// Ixtiyoriy rang override (masalan navy fonda oq tugma uchun).
  final Color? bgColor;
  final Color? fgColor;
  const SButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.kind = BtnKind.primary,
    this.loading = false,
    this.large = false,
    this.bgColor,
    this.fgColor,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    Color bg;
    Color fg;
    switch (kind) {
      case BtnKind.primary:
        bg = c.accent;
        fg = Colors.white;
        break;
      case BtnKind.soft:
        bg = c.accentSoft;
        fg = c.accent;
        break;
      case BtnKind.ghost:
        bg = c.surface3;
        fg = c.text;
        break;
      case BtnKind.danger:
        bg = c.redSoft;
        fg = c.red;
        break;
      case BtnKind.outline:
        bg = Colors.transparent;
        fg = c.text;
        break;
    }
    if (bgColor != null) bg = bgColor!;
    if (fgColor != null) fg = fgColor!;
    final disabled = onTap == null || loading;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(large ? 17 : AppSizes.btn),
        child: InkWell(
          borderRadius: BorderRadius.circular(large ? 17 : AppSizes.btn),
          onTap: disabled ? null : onTap,
          child: Container(
            height: large ? 56 : 50,
            alignment: Alignment.center,
            decoration: kind == BtnKind.outline
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(large ? 17 : AppSizes.btn),
                    border: Border.all(color: c.borderStrong, width: 1.5),
                  )
                : null,
            child: loading
                ? SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
                      Text(label,
                          style: TextStyle(color: fg, fontSize: large ? 17 : 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Baho rangli qutichasi (jadval/katak uchun).
class GradeBox extends StatelessWidget {
  final num? grade;
  final double size;
  const GradeBox(this.grade, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    if (grade == null) {
      return SizedBox(width: size, height: size, child: Center(child: Text('—', style: TextStyle(color: c.faint))));
    }
    // Web bilan bir xil: yagona yashil shkala (1 och → 5 to'q), to'q fonda matn oq.
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: gradeCellBg(grade!), borderRadius: BorderRadius.circular(8)),
      child: Text('${grade! % 1 == 0 ? grade!.toInt() : grade}',
          style: TextStyle(color: gradeCellFg(grade!), fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}
