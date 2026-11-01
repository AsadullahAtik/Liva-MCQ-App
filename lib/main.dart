import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/staff/staff_shell.dart';

final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  Api.onExpired = () async {
    if (!Api.loggedIn) return;
    await Api.logout();
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen(notice: 'সেশনের মেয়াদ শেষ, আবার লগইন করুন')),
      (_) => false,
    );
  };
  runApp(const McqApp());
}

class McqApp extends StatelessWidget {
  const McqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live MCQ',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B5BDB)),
      ),
      home: !Api.loggedIn
          ? const LoginScreen()
          : (Api.user?['role'] == 'STUDENT' ? const HomeScreen() : const StaffShell()),
    );
  }
}
