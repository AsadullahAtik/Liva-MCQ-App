import 'dart:async';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../live.dart';
import '../../util.dart';
import 'exam_editor.dart';

/// পরীক্ষার বিস্তারিত: পরিসংখ্যান, লাইভ ফলাফল-বোর্ড, প্রকাশ/সম্পাদনা/মুছা.
class ExamDetail extends StatefulWidget {
  const ExamDetail({super.key, required this.examId});
  final int examId;

  @override
  State<ExamDetail> createState() => _ExamDetailState();
}

class _ExamDetailState extends State<ExamDetail> {
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  bool _busy = false;
  StreamSubscription? _sub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _sub = Bus.events.stream.listen((ev) {
      final id = ev['examId'];
      if (id is num && id.toInt() != widget.examId) return;
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
      final d = await Api.adminExam(widget.examId);
      List<Map<String, dynamic>> rows = [];
      try {
        final b = await Api.adminResults(widget.examId);
        rows = (b['rows'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on ApiError {
        // এখনো কেউ জমা দেয়নি
      }
      if (!mounted) return;
      setState(() {
        _d = d;
        _rows = rows;
        _error = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.status == 404) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() f, String okMsg) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) toast(context, okMsg);
      await _load();
    } on ApiError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator()),
      );
    }
    final e = Map<String, dynamic>.from(d['exam'] as Map);
    final stats = d['stats'] == null ? null : Map<String, dynamic>.from(d['stats'] as Map);
    final qs = (d['questions'] as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    final published = e['published'] == true;
    final attempts = (e['attempts'] as num).toInt();
    final canEdit = attempts == 0 && !published;
    return Scaffold(
      appBar: AppBar(
        title: Text('${e['title']}', style: const TextStyle(fontSize: 17)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                if (!canEdit) {
                  toast(context, 'কেউ শুরু করলে বা প্রকাশের পর সম্পাদনা চলে না');
                  return;
                }
                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ExamEditor(detail: d)));
                if (ok == true) _load();
              } else if (v == 'delete') {
                if (await confirm(context, 'পরীক্ষা মুছবেন?', 'প্রশ্ন ও সব ফলাফল মুছে যাবে।', ok: 'মুছুন')) {
                  try {
                    await Api.deleteExam(widget.examId);
                    if (mounted) Navigator.of(context).pop();
                  } on ApiError catch (x) {
                    if (mounted) toast(context, x.message);
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
              PopupMenuItem(value: 'delete', child: Text('মুছুন')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e['className']} · ${e['qCount']}টি প্রশ্ন · ${e['durationMin']} মিনিট'),
                  Text('পূর্ণমান ${fmtNum(e['total'] as num)} · ভুলে −${fmtNum(e['neg'] as num)} · shuffle ${e['shuffle'] == true ? 'চালু' : 'বন্ধ'}'),
                  if (parseTime(e['startAt']) != null || parseTime(e['endAt']) != null)
                    Text('সময়: ${fmtWhen(parseTime(e['startAt']))} → ${fmtWhen(parseTime(e['endAt']))}'),
                  const SizedBox(height: 4),
                  Text('$attempts জন অংশ নিয়েছে · ${published ? 'ফলাফল প্রকাশিত' : 'ফলাফল অপ্রকাশিত'}'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() => Api.setPublished(widget.examId, !published), published ? 'প্রকাশ বন্ধ হয়েছে' : 'ফলাফল প্রকাশ হয়েছে'),
                    icon: Icon(published ? Icons.visibility_off : Icons.campaign),
                    label: Text(published ? 'প্রকাশ তুলে নিন' : 'ফলাফল প্রকাশ করুন'),
                  ),
                ]),
              ),
            ),
            if (stats != null && (stats['n'] as num) > 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(spacing: 20, runSpacing: 8, children: [
                    _kv('জমা', '${stats['n']}'),
                    _kv('গড়', fmtNum(stats['avg'] as num)),
                    _kv('সর্বোচ্চ', fmtNum(stats['max'] as num)),
                    _kv('সর্বনিম্ন', fmtNum(stats['min'] as num)),
                    _kv('পাস', '${stats['passPercent']}%'),
                    _kv('গড় সময়', fmtClock((stats['avgTimeSec'] as num).toInt())),
                  ]),
                ),
              ),
            const SizedBox(height: 4),
            Text('ফলাফল-বোর্ড (লাইভ)', style: Theme.of(context).textTheme.titleMedium),
            if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('এখনো কেউ জমা দেয়নি')),
            for (final r in _rows)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${r['rank']}')),
                  title: Text('${r['name']} (${r['roll']})'),
                  subtitle: Text('সঠিক ${r['correct']} · ভুল ${r['wrong']} · ফাঁকা ${r['blank']} · ${fmtClock((r['timeSec'] as num).toInt())}'),
                  trailing: Text(fmtNum(r['marks'] as num), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(height: 8),
            Text('প্রশ্নসমূহ', style: Theme.of(context).textTheme.titleMedium),
            for (var i = 0; i < qs.length; i++) _qCard(i, qs[i], stats),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(k, style: Theme.of(context).textTheme.bodySmall),
      ]);

  Widget _qCard(int i, Map<String, dynamic> q, Map<String, dynamic>? stats) {
    final opts = (q['options'] as List).map((x) => '$x').toList();
    final correct = (q['correct'] as num).toInt();
    String? st;
    if (stats != null && stats['questions'] is List && i < (stats['questions'] as List).length) {
      final s = (stats['questions'] as List)[i] as Map;
      st = 'সঠিক ${s['correct']} · ভুল ${s['wrong']} · ফাঁকা ${s['blank']}';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q['text']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (var k = 0; k < opts.length; k++)
            Text('${['ক', 'খ', 'গ', 'ঘ'][k % 4]}. ${opts[k]}${k == correct ? '  ✓' : ''}',
                style: TextStyle(color: k == correct ? Colors.green.shade700 : null, fontWeight: k == correct ? FontWeight.w700 : null)),
          if (st != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(st, style: Theme.of(context).textTheme.bodySmall)),
        ]),
      ),
    );
  }
}
