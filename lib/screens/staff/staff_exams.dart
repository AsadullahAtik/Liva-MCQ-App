import 'dart:async';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../live.dart';
import '../../util.dart';
import 'exam_detail.dart';
import 'exam_editor.dart';

class StaffExams extends StatefulWidget {
  const StaffExams({super.key});

  @override
  State<StaffExams> createState() => _StaffExamsState();
}

class _StaffExamsState extends State<StaffExams> {
  List<Map<String, dynamic>> _exams = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _sub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _sub = Bus.events.stream.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _load);
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await Api.adminExams();
      if (!mounted) return;
      setState(() {
        _exams = l;
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ExamEditor()));
          if (ok == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('নতুন পরীক্ষা'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  if (_error != null)
                    Card(color: cs.errorContainer, child: ListTile(leading: const Icon(Icons.wifi_off), title: Text(_error!))),
                  if (_error == null && _exams.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('কোনো পরীক্ষা নেই'))),
                  for (final e in _exams)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamDetail(examId: (e['id'] as num).toInt())));
                          _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${e['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
                              Chip(
                                label: Text(e['published'] == true ? 'প্রকাশিত' : 'অপ্রকাশিত', style: const TextStyle(fontSize: 12)),
                                backgroundColor: e['published'] == true ? Colors.green.withAlpha(40) : Colors.orange.withAlpha(40),
                                visualDensity: VisualDensity.compact,
                              ),
                            ]),
                            Text(
                              '${e['className']} · ${e['qCount']}টি প্রশ্ন · ${e['durationMin']} মিনিট · ${e['attempts']} জন দিয়েছে',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (parseTime(e['startAt']) != null || parseTime(e['endAt']) != null)
                              Text(
                                'সময়: ${fmtWhen(parseTime(e['startAt']))} → ${fmtWhen(parseTime(e['endAt']))}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ]),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
