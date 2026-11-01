import 'package:flutter/material.dart';

import '../../api.dart';
import '../../util.dart';

/// শুধু Admin: শ্রেণি ও শাখা.
class StaffClasses extends StatefulWidget {
  const StaffClasses({super.key});

  @override
  State<StaffClasses> createState() => _StaffClassesState();
}

class _StaffClassesState extends State<StaffClasses> {
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
      final l = await Api.adminClasses();
      if (!mounted) return;
      setState(() {
        _classes = l;
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

  Future<String?> _ask(String title, String label) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (x) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(x), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(x, c.text.trim()), child: const Text('যোগ করুন')),
        ],
      ),
    );
    c.dispose();
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> _do(Future<void> Function() f) async {
    try {
      await f();
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final n = await _ask('নতুন শ্রেণি', 'শ্রেণির নাম');
          if (n != null) _do(() => Api.addClass(n));
        },
        icon: const Icon(Icons.add),
        label: const Text('শ্রেণি'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  if (_error != null) ListTile(leading: const Icon(Icons.wifi_off), title: Text(_error!)),
                  for (final c in _classes)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${c['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, children: [
                            for (final s in '${c['sections'] ?? ''}'.split(',').where((e) => e.trim().isNotEmpty)) Chip(label: Text(s.trim()), visualDensity: VisualDensity.compact),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text('শাখা'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                final n = await _ask('নতুন শাখা', 'শাখার নাম');
                                if (n != null) _do(() => Api.addSection((c['id'] as num).toInt(), n));
                              },
                            ),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
