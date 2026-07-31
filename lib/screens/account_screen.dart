import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../api/api_client.dart';

/// Akkaunt sozlamalari — parolni almashtirish (joriy + yangi + takror).
/// Web `account/AccountPage.tsx`ga mos: `PUT /auth/account`
/// `{currentPassword, newPassword}`.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureRepeat = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_current.text.isEmpty || _next.text.isEmpty || _repeat.text.isEmpty) {
      setState(() => _error = "Barcha maydonlarni to'ldiring");
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = "Yangi parol kamida 8 ta belgidan iborat bo'lishi kerak");
      return;
    }
    if (_next.text != _repeat.text) {
      setState(() => _error = 'Yangi parollar mos kelmadi');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ApiClient.dio.put('/auth/account', data: {
        'currentPassword': _current.text,
        'newPassword': _next.text,
      });
      if (!ApiClient.ok(res)) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = ApiClient.errorMessage(res, "Parolni o'zgartirib bo'lmadi");
        });
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Parol o'zgartirildi")));
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = "Serverga ulanib bo'lmadi";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'Akkaunt',
      scrollable: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Parolni almashtirish',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
            const SizedBox(height: 4),
            Text('Xavfsizlik uchun joriy parolingizni kiriting',
                style: TextStyle(fontSize: 12.5, color: c.muted)),
            const SizedBox(height: 16),
            _PassField(
              label: 'Joriy parol',
              controller: _current,
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 12),
            _PassField(
              label: 'Yangi parol',
              controller: _next,
              obscure: _obscureNext,
              hint: 'Kamida 8 ta belgi',
              onToggle: () => setState(() => _obscureNext = !_obscureNext),
            ),
            const SizedBox(height: 12),
            _PassField(
              label: 'Yangi parolni takrorlang',
              controller: _repeat,
              obscure: _obscureRepeat,
              onToggle: () => setState(() => _obscureRepeat = !_obscureRepeat),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: c.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SButton('Saqlash', icon: Icons.check_rounded, loading: _busy, large: true, onTap: _submit),
          ],
        ),
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String hint;
  const _PassField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.hint = '••••••••',
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.text)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: c.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.faint),
            prefixIcon: Icon(Icons.lock_outline, color: c.faint, size: 19),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: c.faint, size: 19),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: c.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
