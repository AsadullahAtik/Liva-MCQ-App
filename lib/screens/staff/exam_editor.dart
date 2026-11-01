import 'package:flutter/material.dart';

import '../../api.dart';
import '../../util.dart';

class _Q {
  final text = TextEditingController();
  final opts = List.generate(4, (_) => TextEditingController());
  int correct = 0;
  void dispose() {
    text.dispose();
    for (final o in opts) {
      o.dispose();
    }
  }
}

/// পরীক্ষা তৈরি / সম্পাদনা (detail দিলে সম্পাদনা).
class ExamEditor extends StatefulWidget {
  const ExamEditor({super.key, this.detail});
  final Map<String, dynamic>? detail;

  @override
  State<ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<ExamEditor> {
  final _title = TextEditingController();
  final _dur = TextEditingController(text: '30');
  final _perQ = TextEditingController(text: '1');
  final _neg = TextEditingController(text: '0');
  final List<_Q> _qs = [];
  List<Map<String, dynamic>> _classes = [];
  int? _classId;
  bool _shuffle = true;
  DateTime? _start, _end;
  bool _busy = false;
  String? _error;
  bool get _editing => widget.detail != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final d = widget.detail;
    if (d != null) {
      final e = Map<String, dynamic>.from(d['exam'] as Map);
      _title.text = '${e['title']}';
      _dur.text = '${e['durationMin']}';
      _perQ.text = fmtNum(e['perQ'] as num);
      _neg.text = fmtNum(e['neg'] as num);
      _classId = (e['classId'] as num).toInt();
      _shuffle = e['shuffle'] == true;
      _start = parseTime(e['startAt']);
      _end = parseTime(e['endAt']);
      for (final x in d['questions'] as List) {
        final q = _Q();
        final m = Map<String, dynamic>.from(x as Map);
        q.text.text = '${m['text']}';
        final o = m['options'] as List;
        for (var i = 0; i < 4 && i < o.length; i++) {
          q.opts[i].text = '${o[i]}';
        }
        q.correct = (m['correct'] as num).toInt();
        _qs.add(q);
      }
    } else {
      _qs.add(_Q());
    }
    try {
      final cs = await Api.adminClasses();
      if (!mounted) return;
      setState(() {
        _classes = cs;
        _classId ??= cs.isNotEmpty ? (cs.first['id'] as num).toInt() : null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _dur, _perQ, _neg]) {
      c.dispose();
    }
    for (final q in _qs) {
      q.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'পরীক্ষার নাম দিন';
    if (_classId == null) return 'শ্রেণি বেছে নিন';
    final dur = int.tryParse(_dur.text.trim());
    if (dur == null || dur <= 0) return 'সময় (মিনিট) ঠিক নয়';
    if (double.tryParse(_perQ.text.trim()) == null || double.parse(_perQ.text.trim()) <= 0) return 'প্রতি প্রশ্নের নম্বর ঠিক নয়';
    final neg = double.tryParse(_neg.text.trim());
    if (neg == null || neg < 0) return 'ভুলে কাটা নম্বর ঠিক নয়';
    if (_start != null && _end != null && !_end!.isAfter(_start!)) return 'শেষের সময় শুরুর পরে হতে হবে';
    if (_qs.isEmpty) return 'কমপক্ষে একটি প্রশ্ন দিন';
    for (var i = 0; i < _qs.length; i++) {
      final q = _qs[i];
      if (q.text.text.trim().isEmpty || q.opts.any((o) => o.text.trim().isEmpty)) return 'প্রশ্ন ${i + 1}: লেখা ও ৪টি অপশনই দিন';
    }
    return null;
  }

  Future<void> _save() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      'title': _title.text.trim(),
      'classId': _classId,
      'durationMin': int.parse(_dur.text.trim()),
      'perQ': double.parse(_perQ.text.trim()),
      'neg': double.parse(_neg.text.trim()),
      'shuffle': _shuffle,
      'startAt': _start?.toUtc().toIso8601String(),
      'endAt': _end?.toUtc().toIso8601String(),
      'questions': [
        for (final q in _qs) {'text': q.text.text.trim(), 'options': [for (final o in q.opts) o.text.trim()], 'correct': q.correct},
      ],
    };
    try {
      if (_editing) {
        await Api.updateExam(((widget.detail!['exam'] as Map)['id'] as num).toInt(), body);
      } else {
        await Api.createExam(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _timeRow(String label, DateTime? v, void Function(DateTime?) set) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(v == null ? 'সীমা নেই' : fmtWhen(v)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (v != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => set(null))),
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: () async {
              final t = await pickDateTime(context, v);
              if (t != null) setState(() => set(t));
            },
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'পরীক্ষা সম্পাদনা' : 'নতুন পরীক্ষা')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
            ),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'পরীক্ষার নাম', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _classId,
            decoration: const InputDecoration(labelText: 'শ্রেণি', border: OutlineInputBorder()),
            items: [for (final c in _classes) DropdownMenuItem(value: (c['id'] as num).toInt(), child: Text('${c['name']}'))],
            onChanged: (v) => setState(() => _classId = v),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _dur,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'সময় (মিনিট)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _perQ,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'প্রতি প্রশ্নে', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _neg,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'ভুলে কাটা', border: OutlineInputBorder()),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('প্রশ্ন ও অপশন এলোমেলো (shuffle)'),
            value: _shuffle,
            onChanged: (v) => setState(() => _shuffle = v),
          ),
          _timeRow('শুরুর সময় (ঐচ্ছিক)', _start, (v) => _start = v),
          _timeRow('শেষের সময় (ঐচ্ছিক)', _end, (v) => _end = v),
          const Divider(),
          Text('প্রশ্ন (${_qs.length})', style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _qs.length; i++) _qEditor(i),
          OutlinedButton.icon(onPressed: () => setState(() => _qs.add(_Q())), icon: const Icon(Icons.add), label: const Text('প্রশ্ন যোগ করুন')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_editing ? 'সংরক্ষণ' : 'পরীক্ষা তৈরি করুন'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _qEditor(int i) {
    final q = _qs[i];
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Text('প্রশ্ন ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _qs.length <= 1
                  ? null
                  : () => setState(() => _qs.removeAt(i)),
            ),
          ]),
          TextField(controller: q.text, maxLines: null, decoration: const InputDecoration(labelText: 'প্রশ্ন', border: OutlineInputBorder())),
          for (var k = 0; k < 4; k++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Radio<int>(value: k, groupValue: q.correct, onChanged: (v) => setState(() => q.correct = v ?? 0)),
                Expanded(
                  child: TextField(
                    controller: q.opts[k],
                    decoration: InputDecoration(labelText: 'অপশন ${['ক', 'খ', 'গ', 'ঘ'][k]}', border: const OutlineInputBorder(), isDense: true),
                  ),
                ),
              ]),
            ),
          const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(top: 4), child: Text('গোল বোতামে চাপ দিয়ে সঠিক উত্তর বাছুন', style: TextStyle(fontSize: 12)))),
        ]),
      ),
    );
  }
}
