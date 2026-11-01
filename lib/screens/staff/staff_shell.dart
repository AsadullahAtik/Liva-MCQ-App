import 'package:flutter/material.dart';

import '../../api.dart';
import '../../live.dart';
import '../login.dart';
import '../password.dart';
import 'staff_classes.dart';
import 'staff_exams.dart';
import 'staff_students.dart';
import 'staff_teachers.dart';

/// Admin ও শিক্ষকের মূল পর্দা. শিক্ষক শুধু পরীক্ষা ও ছাত্র দেখে; Admin শ্রেণি ও শিক্ষকও.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _tab = 0;
  late final Live _live;
  bool get _admin => Api.user?['role'] == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _live = Live((ev) => Bus.events.add(ev))..start();
  }

  @override
  void dispose() {
    _live.stop();
    super.dispose();
  }

  Future<void> _logout() async {
    _live.stop();
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.user ?? {};
    final pages = <Widget>[
      const StaffExams(),
      const StaffStudents(),
      if (_admin) const StaffClasses(),
      if (_admin) const StaffTeachers(),
    ];
    final items = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'পরীক্ষা'),
      const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'ছাত্র'),
      if (_admin) const NavigationDestination(icon: Icon(Icons.class_outlined), selectedIcon: Icon(Icons.class_), label: 'শ্রেণি'),
      if (_admin) const NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'শিক্ষক'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('${u['name'] ?? ''} · ${_admin ? 'Admin' : 'শিক্ষক'}', style: const TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            icon: const Icon(Icons.key),
            tooltip: 'পাসওয়ার্ড বদল',
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'লগআউট'),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: items),
    );
  }
}
