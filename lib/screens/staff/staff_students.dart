import 'package:flutter/material.dart';

import '../../api.dart';
import '../../util.dart';
import '../password.dart';

class StaffStudents extends StatefulWidget {
  const StaffStudents({super.key});

  @override
  State<StaffStudents> createState() => _StaffStudentsState();
}

class _StaffStudentsState extends State<StaffStudents> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await Api.adminStudents();
      if (!mounted) return;
      setState(() {
        _all = l;
        _loading = false;
        _error = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = _all.where((s) => q.isEmpty || '${s['name']}'.toLowerCase().contains(q) || '${s['roll']}'.toLowerCase().contains(q)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'নাম বা রোল খুঁজুন', border: OutlineInputBorder(), isDense: true),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_error != null) ListTile(leading: const Icon(Icons.wifi_off), title: Text(_error!)),
                    if (_error == null && list.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('কোনো ছাত্র নেই'))),
                    for (final s in list)
                      ListTile(
                        leading: CircleAvatar(child: Text('${s['name']}'.isEmpty ? '?' : '${s['name']}'.characters.first)),
                        title: Text('${s['name']}'),
                        subtitle: Text('রোল ${s['roll']} · ${s['className'] ?? ''}${s['section'] != null ? ' (${s['section']})' : ''}'),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentReportScreen(student: s)));
                          _load();
                        },
                      ),
                  ],
                ),
        ),
      ),
    ]);
  }
}

class StudentReportScreen extends StatefulWidget {
  const StudentReportScreen({super.key, required this.student});
  final Map<String, dynamic> student;

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  Map<String, dynamic>? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.studentReport((widget.student['id'] as num).toInt());
      if (mounted) setState(() => _r = r);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _enroll() async {
    List<Map<String, dynamic>> classes;
    try {
      classes = await Api.adminClasses();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
      return;
    }
    if (!mounted || classes.isEmpty) return;
    int classId = (_r?['student']?['classId'] as num?)?.toInt() ?? (classes.first['id'] as num).toInt();
    if (!classes.any((c) => (c['id'] as num).toInt() == classId)) classId = (classes.first['id'] as num).toInt();
    String section = '${_r?['student']?['section'] ?? ''}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        final cur = classes.firstWhere((x) => (x['id'] as num).toInt() == classId);
        final secs = '${cur['sections'] ?? ''}'.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (!secs.contains(section)) section = '';
        return AlertDialog(
          title: const Text('শ্রেণি/শাখা বদল'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: classId,
              items: [for (final x in classes) DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'))],
              onChanged: (v) => setD(() => classId = v ?? classId),
            ),
            DropdownButtonFormField<String>(
              value: section,
              items: [const DropdownMenuItem(value: '', child: Text('শাখা ছাড়া')), for (final s in secs) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setD(() => section = v ?? ''),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('সংরক্ষণ')),
          ],
        );
      }),
    );
    if (ok != true) return;
    try {
      await Api.enroll((widget.student['id'] as num).toInt(), classId, section);
      if (mounted) toast(context, 'বদল হয়েছে');
      _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    final r = _r;
    final admin = Api.user?['role'] == 'ADMIN';
    return Scaffold(
      appBar: AppBar(title: Text('${s['name']}', style: const TextStyle(fontSize: 17))),
      body: r == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              Card(
                child: ListTile(
                  title: Text('রোল ${s['roll']}'),
                  subtitle: Text('${(r['student'] as Map)['className'] ?? ''}${(r['student'] as Map)['section'] != null ? ' (${(r['student'] as Map)['section']})' : ''}\n'
                      '${r['taken']} / ${r['totalExams']} পরীক্ষা দিয়েছে'),
                  isThreeLine: true,
                  trailing: admin
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.key), tooltip: 'পাসওয়ার্ড রিসেট', onPressed: () => resetPasswordDialog(context, (s['id'] as num).toInt(), '${s['name']}')),
                          IconButton(icon: const Icon(Icons.swap_horiz), tooltip: 'শ্রেণি বদল', onPressed: _enroll),
                        ])
                      : null,
                ),
              ),
              for (final x in (r['exams'] as List))
                Card(
                  child: ListTile(
                    title: Text('${(x as Map)['title']}'),
                    subtitle: Text(x['submitted'] == true
                        ? (x['published'] == true || x['marks'] != null
                            ? 'নম্বর ${fmtNum(x['marks'] as num)}/${fmtNum(x['total'] as num)} · র‍্যাংক ${x['rank']}/${x['participants']}'
                            : 'জমা দিয়েছে')
                        : (x['started'] == true ? 'শুরু করেছে, জমা দেয়নি' : 'দেয়নি')),
                    trailing: Icon(x['submitted'] == true ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: x['submitted'] == true ? Colors.green : Colors.grey),
                  ),
                ),
            ]),
    );
  }
}
