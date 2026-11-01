import 'package:flutter/material.dart';

import '../api.dart';
import '../util.dart';

/// প্রকাশিত ফলাফল: নম্বর, ভুল-শুদ্ধ রিভিউ ও র‍্যাংক তালিকা.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.examId, required this.title});
  final int examId;
  final String title;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? _res;
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.result(widget.examId);
      List<Map<String, dynamic>> rows = [];
      try {
        final b = await Api.leaderboard(widget.examId);
        rows = (b['rows'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } on ApiError {
        // র‍্যাংক তালিকা না পেলেও ফলাফল দেখাই
      }
      if (!mounted) return;
      setState(() {
        _res = r;
        _rows = rows;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, style: const TextStyle(fontSize: 17)),
          bottom: const TabBar(tabs: [Tab(text: 'ফলাফল'), Tab(text: 'র‍্যাংক')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : TabBarView(children: [_resultTab(context), _boardTab(context)]),
      ),
    );
  }

  Widget _stat(BuildContext c, String label, String value, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
        ),
      );

  Widget _resultTab(BuildContext c) {
    final r = _res!;
    final review = (r['review'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Theme.of(c).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Text('${fmtNum(r['marks'] as num)} / ${fmtNum(r['total'] as num)}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('র‍্যাংক ${r['rank']} / ${r['participants']} · সময় ${fmtClock((r['timeSec'] as num).toInt())}'),
            ]),
          ),
        ),
        Row(children: [
          _stat(c, 'সঠিক', '${r['correct']}', Colors.green.shade700),
          _stat(c, 'ভুল', '${r['wrong']}', Colors.red.shade700),
          _stat(c, 'ফাঁকা', '${r['blank']}', Colors.blueGrey),
        ]),
        const SizedBox(height: 6),
        Text('উত্তর পর্যালোচনা', style: Theme.of(c).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (var i = 0; i < review.length; i++) _reviewCard(c, i, review[i]),
      ],
    );
  }

  Widget _reviewCard(BuildContext c, int i, Map<String, dynamic> q) {
    final opts = (q['options'] as List).map((e) => '$e').toList();
    final correct = (q['correct'] as num).toInt(), mine = (q['mine'] as num).toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q['text']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          for (var k = 0; k < opts.length; k++)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: k == correct
                    ? Colors.green.withAlpha(40)
                    : (k == mine ? Colors.red.withAlpha(40) : null),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: k == correct ? Colors.green : (k == mine ? Colors.red : Colors.transparent)),
              ),
              child: Row(children: [
                Expanded(child: Text('${['ক', 'খ', 'গ', 'ঘ'][k % 4]}. ${opts[k]}')),
                if (k == correct) const Icon(Icons.check_circle, size: 18, color: Colors.green),
                if (k == mine && k != correct) const Icon(Icons.cancel, size: 18, color: Colors.red),
              ]),
            ),
          if (mine < 0) const Text('উত্তর দেননি', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _boardTab(BuildContext c) {
    if (_rows.isEmpty) return const Center(child: Text('র‍্যাংক তালিকা পাওয়া যায়নি'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      itemBuilder: (ctx, i) {
        final r = _rows[i];
        final me = r['me'] == true;
        return Card(
          color: me ? Theme.of(ctx).colorScheme.primaryContainer : null,
          child: ListTile(
            leading: CircleAvatar(child: Text('${r['rank']}')),
            title: Text('${r['name']}${me ? ' (আপনি)' : ''}', style: TextStyle(fontWeight: me ? FontWeight.w700 : FontWeight.w500)),
            subtitle: Text('সঠিক ${r['correct']} · ভুল ${r['wrong']} · সময় ${fmtClock((r['timeSec'] as num).toInt())}'),
            trailing: Text(fmtNum(r['marks'] as num), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}
