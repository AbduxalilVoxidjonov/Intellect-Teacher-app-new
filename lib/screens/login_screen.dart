import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Kirish ekrani — o'qituvchi login (email/telefon) + parol.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    // BUG-S7: bo'sh maydonlar bilan haqiqiy POST ketardi va serverning 401'i
    // "Login yoki parol noto'g'ri" bo'lib ko'rinardi — bu chalg'ituvchi.
    // Avval MAHALLIY tekshiramiz, so'rov umuman yuborilmaydi.
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Login va parolni kiriting');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context.read<Session>().login(email, password);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      // Navy fon — logoning navy foni bilan bir xil, logo chekkasiz qo'shilib ketadi.
      backgroundColor: kBrandNavy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(
                    child: SizedBox(
                      width: 128,
                      height: 128,
                      child: Image(image: AssetImage('assets/logo.jpg'), fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Xush kelibsiz",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text("O'qituvchi akkauntingiz bilan kiring",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 28),
                  _Field(
                    controller: _email,
                    hint: 'Login (email yoki telefon)',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    hint: 'Parol',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onSubmit: (_) => _submit(),
                    trailing: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: c.faint, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: c.red, size: 19),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13.5))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SButton('Kirish',
                      icon: Icons.login_rounded,
                      loading: _loading,
                      large: true,
                      bgColor: Colors.white,
                      fgColor: kBrandNavy,
                      onTap: _submit),
                  const SizedBox(height: 18),
                  const Text('Intellect Teacher',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmit;
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.onSubmit,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmit,
      style: TextStyle(color: c.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint),
        prefixIcon: Icon(icon, color: c.faint, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }
}
