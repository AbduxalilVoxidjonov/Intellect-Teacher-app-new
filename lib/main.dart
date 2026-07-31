import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/push.dart';
import 'services/session.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase + push (xato bo'lsa ilova baribir ishlaydi).
  try {
    await Firebase.initializeApp();
    await PushService.instance.init();
  } catch (e) {
    debugPrint('[firebase] init error: $e');
  }
  final session = Session();
  await session.init();
  // Allaqachon kirgan bo'lsa — token'ni backend'ga yuboramiz.
  if (session.isAuthed) {
    PushService.instance.syncToken();
  }
  runApp(
    ChangeNotifierProvider.value(value: session, child: const TeacherApp()),
  );
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final colors = session.isDark ? AppColors.dark : AppColors.light;
    return MaterialApp(
      title: "Intellect Teacher",
      debugShowCheckedModeBanner: false,
      theme: buildMaterialTheme(colors),
      builder: (context, child) => AppTheme(colors: colors, child: child ?? const SizedBox()),
      home: !session.ready
          ? const _Splash()
          : (session.isAuthed ? const ShellScreen() : const LoginScreen()),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    // Navy fon — logoning navy foni bilan bir xil, chekkasiz qo'shilib ketadi.
    return const Scaffold(
      backgroundColor: kBrandNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Image(image: AssetImage('assets/logo.jpg'), fit: BoxFit.contain),
            ),
            SizedBox(height: 26),
            Text("O'quv markaziga xush kelibsiz",
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            SizedBox(height: 30),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
            ),
          ],
        ),
      ),
    );
  }
}
