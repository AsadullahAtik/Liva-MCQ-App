import 'package:flutter/material.dart';

import '../api.dart';
import '../util.dart';

/// নিজের পাসওয়ার্ড বদল (সব ভূমিকার জন্য).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _old = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_old.text.isEmpty) return setState(() => _error = 'বর্তমান পাসওয়ার্ড দিন');
    if (_new1.text.length < 4) return setState(() => _error = 'নতুন পাসওয়ার্ড কমপক্ষে ৪ অক্ষর');
    if (_new1.text != _new2.text) return setState(() => _error = 'নতুন পাসওয়ার্ড দুইবার মিলছে না');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.changePassword(_old.text, _new1.text);
      if (!mounted) return;
      toast(context, 'পাসওয়ার্ড বদলেছে');
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('পাসওয়ার্ড বদল')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
            child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
          ),
        TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _new1, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _new2, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড আবার', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('বদলান'),
          ),
        ),
      ]),
    );
  }
}

/// Admin: অন্য কারও পাসওয়ার্ড বদলে দেওয়ার ডায়ালগ.
Future<void> resetPasswordDialog(BuildContext context, int userId, String who) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (x) => AlertDialog(
      title: Text('$who — নতুন পাসওয়ার্ড'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড (কমপক্ষে ৪ অক্ষর)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('বাতিল')),
        FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('বদলান')),
      ],
    ),
  );
  final pw = c.text;
  c.dispose();
  if (ok != true) return;
  try {
    await Api.resetPassword(userId, pw);
    if (context.mounted) toast(context, 'পাসওয়ার্ড বদলানো হয়েছে');
  } on ApiError catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}
