import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../util.dart';

/// পরীক্ষা দেওয়ার পর্দা: সার্ভারের ঘড়ি মেনে টাইমার, অটোসেভ, শেষ হলে অটো-জমা.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.exam});
  final Map<String, dynamic> exam;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  int _attemptId = 0;
  List<Map<String, dynamic>> _qs = [];
  List<int> _answers = [];
  int _idx = 0;
  late DateTime _deadline;
  Duration _skew = Duration.zero; // সার্ভার সময় − ফোনের সময়
  int _left = 0;
  Timer? _tick;
  Timer? _save;
  bool _dirty = false;
  bool _submitting = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _save?.cancel();
    if (_dirty && !_done && _attemptId != 0) {
      Api.saveAnswers(_attemptId, _answers).catchError((_) {});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _flush();
    if (s == AppLifecycleState.resumed) _recalc();
  }

  Future<void> _begin() async {
    try {
      final r = await Api.start((widget.exam['id'] as num).toInt());
      final dl = parseTime(r['deadline']);
      final now = parseTime(r['serverNow']);
      if (dl == null) throw ApiError(0, 'সার্ভারের উত্তর ঠিক নয়');
      _skew = now == null ? Duration.zero : now.difference(DateTime.now());
      _deadline = dl;
      _attemptId = (r['attemptId'] as num).toInt();
      _qs = (r['questions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final saved = (r['answers'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      _answers = List<int>.generate(_qs.length, (i) => i < saved.length ? saved[i] : -1);
      _recalc();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _recalc());
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _recalc() {
    if (_done || _loading || _error != null) return;
    final left = _deadline.difference(DateTime.now().add(_skew)).inSeconds;
    if (mounted) setState(() => _left = left);
    if (left <= 0 && !_submitting) _submit(auto: true);
  }

  void _pick(int opt) {
    setState(() => _answers[_idx] = _answers[_idx] == opt ? -1 : opt);
    _dirty = true;
    _save?.cancel();
    _save = Timer(const Duration(seconds: 2), _flush);
  }

  Future<void> _flush() async {
    if (!_dirty || _done || _attemptId == 0) return;
    _dirty = false;
    try {
      await Api.saveAnswers(_attemptId, _answers);
    } catch (_) {
      _dirty = true; // পরের বার আবার চেষ্টা হবে
    }
  }

  Future<void> _confirmSubmit() async {
    final blank = _answers.where((a) => a < 0).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('জমা দেবেন?'),
        content: Text(blank > 0 ? '$blank টি প্রশ্নের উত্তর দেননি। জমা দিলে আর বদলানো যাবে না।' : 'জমা দিলে আর বদলানো যাবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('জমা দিন')),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _done) return;
    _submitting = true;
    _save?.cancel();
    if (mounted) setState(() {});
    try {
      final r = await Api.submit(_attemptId, _answers);
      _done = true;
      _tick?.cancel();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(auto ? 'সময় শেষ' : 'জমা হয়েছে'),
          content: Text('${r['message'] ?? 'আপনার উত্তর জমা হয়েছে।'}\nফলাফল প্রকাশ হলে তালিকায় দেখতে পাবেন।'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      _submitting = false;
      if (!mounted) return;
      setState(() {});
      toast(context, 'জমা হয়নি: ${e.message}${auto ? '' : ' — আবার চেষ্টা করুন'}');
      if (auto && _left <= 0) {
        if (e.status == 0) {
          // নেটওয়ার্কের সমস্যা: কিছুক্ষণ পরে আবার চেষ্টা (সার্ভারের sweeper-ও জমা করে দেবে)
          Timer(const Duration(seconds: 5), () => _submit(auto: true));
        } else {
          // সার্ভার সরাসরি প্রত্যাখ্যান করেছে (যেমন আগেই জমা/সময় পার): আর চেষ্টা নয়
          _done = true;
          _tick?.cancel();
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(appBar: AppBar(title: Text('${widget.exam['title']}')), body: const Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.exam['title']}')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final q = _qs[_idx];
    final opts = (q['options'] as List).map((e) => '$e').toList();
    final low = _left <= 60;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exam['title']}', style: const TextStyle(fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: low ? cs.errorContainer : cs.secondaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 18, color: low ? cs.error : cs.onSecondaryContainer),
              const SizedBox(width: 4),
              Text(fmtClock(_left), style: TextStyle(fontWeight: FontWeight.w700, color: low ? cs.error : cs.onSecondaryContainer)),
            ]),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _qs.length,
              itemBuilder: (c, i) {
                final answered = _answers[i] >= 0, cur = i == _idx;
                return GestureDetector(
                  onTap: () => setState(() => _idx = i),
                  child: Container(
                    width: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cur ? cs.primary : (answered ? cs.primaryContainer : cs.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}', style: TextStyle(color: cur ? cs.onPrimary : cs.onSurface, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('প্রশ্ন ${_idx + 1} / ${_qs.length}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text('${q['text']}', style: const TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                for (var k = 0; k < opts.length; k++)
                  Card(
                    color: _answers[_idx] == k ? cs.primaryContainer : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _answers[_idx] == k ? cs.primary : cs.outlineVariant, width: _answers[_idx] == k ? 2 : 1),
                    ),
                    child: ListTile(
                      onTap: _submitting ? null : () => _pick(k),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: _answers[_idx] == k ? cs.primary : cs.surfaceContainerHighest,
                        child: Text(['ক', 'খ', 'গ', 'ঘ'][k % 4],
                            style: TextStyle(fontSize: 13, color: _answers[_idx] == k ? cs.onPrimary : cs.onSurface)),
                      ),
                      title: Text(opts[k], style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                const SizedBox(height: 4),
                const Text('আবার চাপলে উত্তর মুছে যায়', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(children: [
              OutlinedButton(onPressed: _idx > 0 ? () => setState(() => _idx--) : null, child: const Icon(Icons.chevron_left)),
              const SizedBox(width: 8),
              Expanded(
                child: _idx < _qs.length - 1
                    ? FilledButton.tonal(onPressed: () => setState(() => _idx++), child: const Text('পরের প্রশ্ন'))
                    : FilledButton(
                        onPressed: _submitting ? null : _confirmSubmit,
                        child: _submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('জমা দিন'),
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _idx < _qs.length - 1 ? () => setState(() => _idx++) : null,
                child: const Icon(Icons.chevron_right),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
