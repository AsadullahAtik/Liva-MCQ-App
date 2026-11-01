import 'package:flutter/material.dart';

import '../../api.dart';
import '../../util.dart';
import '../password.dart';

/// শুধু Admin: শিক্ষক যোগ, শ্রেণি নির্ধারণ, মুছা.
class StaffTeachers extends StatefulWidget {
  const StaffTeachers({super.key});

  @override
  State<StaffTeachers> createState() => _StaffTeachersState();
}

class _StaffTeachersState extends State<StaffTeachers> {
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await Api.teachers();
      final c = await Api.adminClasses();
      if (!mounted) return;
      setState(() {
        _teachers = t;
        _classes = c;
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

  String _classNames(List ids) {
    final names = [for (final c in _classes) if (ids.any((i) => (i as num).toInt() == (c['id'] as num).toInt())) '${c['name']}'];
    return names.isEmpty ? 'কোনো শ্রেণি নেই' : names.join(', ');
  }

  Future<List<int>?> _pickClasses(List<int> initial) {
    final sel = {...initial};
    return showDialog<List<int>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('কোন কোন শ্রেণি?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final x in _classes)
                CheckboxListTile(
                  value: sel.contains((x['id'] as num).toInt()),
                  title: Text('${x['name']}'),
                  onChanged: (v) => setD(() => v == true ? sel.add((x['id'] as num).toInt()) : sel.remove((x['id'] as num).toInt())),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(c, sel.toList()), child: const Text('ঠিক আছে')),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final roll = TextEditingController(), name = TextEditingController(), pass = TextEditingController();
    List<int> ids = [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('নতুন শিক্ষক'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'নাম')),
              TextField(controller: roll, decoration: const InputDecoration(labelText: 'লগইন আইডি')),
              TextField(controller: pass, decoration: const InputDecoration(labelText: 'পাসওয়ার্ড')),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () async {
                  final r = await _pickClasses(ids);
                  if (r != null) setD(() => ids = r);
                },
                child: Text(ids.isEmpty ? 'শ্রেণি বাছুন' : _classNames(ids)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('বাতিল')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('যোগ করুন')),
          ],
        ),
      ),
    );
    final body = {'roll': roll.text.trim(), 'name': name.text.trim(), 'password': pass.text, 'classIds': ids};
    roll.dispose();
    name.dispose();
    pass.dispose();
    if (ok != true) return;
    try {
      await Api.addTeacher(body);
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('শিক্ষক')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  if (_error != null) ListTile(leading: const Icon(Icons.wifi_off), title: Text(_error!)),
                  if (_error == null && _teachers.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('কোনো শিক্ষক নেই'))),
                  for (final t in _teachers)
                    Card(
                      child: ListTile(
                        title: Text('${t['name']} (${t['roll']})'),
                        subtitle: Text(_classNames(t['classIds'] as List)),
                        onTap: () async {
                          final r = await _pickClasses([for (final i in t['classIds'] as List) (i as num).toInt()]);
                          if (r == null) return;
                          try {
                            await Api.setTeacherClasses((t['id'] as num).toInt(), r);
                            await _load();
                          } on ApiError catch (e) {
                            if (mounted) toast(context, e.message);
                          }
                        },
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.key), tooltip: 'পাসওয়ার্ড রিসেট', onPressed: () => resetPasswordDialog(context, (t['id'] as num).toInt(), '${t['name']}')),
                          IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (!await confirm(context, 'শিক্ষক মুছবেন?', '${t['name']} আর লগইন করতে পারবেন না।', ok: 'মুছুন')) return;
                            try {
                              await Api.deleteTeacher((t['id'] as num).toInt());
                              await _load();
                            } on ApiError catch (e) {
                              if (mounted) toast(context, e.message);
                            }
                          },
                        ),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
