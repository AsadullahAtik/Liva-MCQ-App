import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../live.dart';
import '../util.dart';
import 'exam.dart';
import 'login.dart';
import 'password.dart';
import 'result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _exams = [];
  bool _loading = true;
  String? _error;
  late final Live _live;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _live = Live((ev) {
      // অন্য ক্লাসের/কাজের ইভেন্ট সার্ভারই ছাঁকে; এখানে শুধু তালিকা নতুন করে আনি
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _load);
    })..start();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _live.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await Api.exams();
      if (!mounted) return;
      setState(() {
        _exams = list;
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

  Future<void> _logout() async {
    _live.stop();
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _open(Map<String, dynamic> e) async {
    final id = (e['id'] as num).toInt();
    final state = e['state'] as String? ?? '';
    if (state == 'published') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(examId: id, title: '${e['title']}')));
    } else if (state == 'open' || state == 'inprogress') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(exam: e)));
    } else if (state == 'pending') {
      toast(context, 'জমা হয়েছে। ফলাফল প্রকাশের অপেক্ষা করুন।');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.user ?? {};
    return Scaffold(
      appBar: AppBar(
        title: Text('${u['name'] ?? ''}', style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            icon: const Icon(Icons.key),
            tooltip: 'পাসওয়ার্ড বদল',
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'লগআউট'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text('${u['className'] ?? ''}  ·  রোল ${u['roll'] ?? ''}', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(leading: const Icon(Icons.wifi_off), title: Text(_error!), subtitle: const Text('টেনে নামিয়ে আবার চেষ্টা করুন')),
                    ),
                  if (_error == null && _exams.isEmpty)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('এখনো কোনো পরীক্ষা নেই'))),
                  for (final e in _exams) _ExamCard(exam: e, onTap: () => _open(e)),
                ],
              ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});
  final Map<String, dynamic> exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = exam['state'] as String? ?? '';
    final start = parseTime(exam['startAt']), end = parseTime(exam['endAt']);
    String label;
    Color color;
    IconData icon;
    switch (state) {
      case 'open':
        label = 'শুরু করুন';
        color = cs.primary;
        icon = Icons.play_arrow_rounded;
        break;
      case 'inprogress':
        label = 'চালিয়ে যান';
        color = Colors.orange.shade800;
        icon = Icons.timelapse;
        break;
      case 'pending':
        label = 'ফলাফল অপেক্ষমাণ';
        color = Colors.blueGrey;
        icon = Icons.hourglass_bottom;
        break;
      case 'published':
        final m = exam['marks'];
        final r = exam['rank'];
        label = 'ফলাফল${m != null ? ': ${fmtNum(m as num)}/${fmtNum(exam['total'] as num)}' : ''}${r != null ? ' · র‍্যাংক $r' : ''}';
        color = Colors.green.shade700;
        icon = Icons.emoji_events_outlined;
        break;
      case 'upcoming':
        label = start != null ? 'শুরু: ${fmtWhen(start)}' : 'আসছে';
        color = Colors.blueGrey;
        icon = Icons.schedule;
        break;
      case 'missed':
        label = 'মিস হয়েছে';
        color = Colors.red.shade700;
        icon = Icons.block;
        break;
      default:
        label = state;
        color = Colors.blueGrey;
        icon = Icons.info_outline;
    }
    final tappable = state == 'open' || state == 'inprogress' || state == 'published' || state == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tappable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${exam['title']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '${exam['qCount']}টি প্রশ্ন · ${exam['durationMin']} মিনিট · পূর্ণমান ${fmtNum(exam['total'] as num)}'
                '${(exam['neg'] as num) > 0 ? ' · ভুলে −${fmtNum(exam['neg'] as num)}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (start != null || end != null)
                Text(
                  'সময়: ${start != null ? fmtWhen(start) : '—'} থেকে ${end != null ? fmtWhen(end) : '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
