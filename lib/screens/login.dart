import 'package:flutter/material.dart';

import '../api.dart';
import '../util.dart';
import 'home.dart';
import 'staff/staff_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.notice});
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController(text: Api.baseUrl);
  final _roll = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _section = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _classes = [];
  int? _classId;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    for (final c in [_server, _roll, _pass, _name, _section, _phone, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClasses() async {
    await Api.setBase(_server.text);
    try {
      final cs = await Api.publicClasses();
      if (!mounted) return;
      setState(() {
        _classes = cs;
        _classId ??= cs.isNotEmpty ? (cs.first['id'] as num).toInt() : null;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _submit() async {
    final roll = _roll.text.trim(), pass = _pass.text;
    if (roll.isEmpty || pass.isEmpty) {
      setState(() => _error = 'রোল ও পাসওয়ার্ড দিন');
      return;
    }
    if (_register && (_name.text.trim().isEmpty || _classId == null)) {
      setState(() => _error = 'নাম ও শ্রেণি দিন');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.setBase(_server.text);
      final res = _register
          ? await Api.register({
              'roll': roll,
              'name': _name.text.trim(),
              'password': pass,
              'classId': _classId,
              'section': _section.text.trim().isEmpty ? null : _section.text.trim(),
              'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              'code': _code.text.trim().isEmpty ? null : _code.text.trim(),
            })
          : await Api.login(roll, pass);
      final role = (res['user'] as Map)['role'];
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => role == 'STUDENT' ? const HomeScreen() : const StaffShell(),
      ));
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.quiz_rounded, size: 56, color: cs.primary),
                  const SizedBox(height: 8),
                  const Text('Live MCQ', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  Text(_register ? 'নতুন ছাত্র নিবন্ধন' : 'লগইন (ছাত্র / শিক্ষক / Admin)', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                    ),
                  if (_register) ...[
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'নাম', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _roll,
                    decoration: const InputDecoration(labelText: 'রোল', border: OutlineInputBorder()),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'পাসওয়ার্ড', border: OutlineInputBorder()),
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),
                  if (_register) ...[
                    const SizedBox(height: 10),
                    if (_classes.isEmpty)
                      OutlinedButton.icon(onPressed: _loadClasses, icon: const Icon(Icons.refresh), label: const Text('শ্রেণির তালিকা আনুন'))
                    else
                      DropdownButtonFormField<int>(
                        value: _classId,
                        decoration: const InputDecoration(labelText: 'শ্রেণি', border: OutlineInputBorder()),
                        items: [
                          for (final c in _classes)
                            DropdownMenuItem(value: (c['id'] as num).toInt(), child: Text('${c['name']}')),
                        ],
                        onChanged: (v) => setState(() => _classId = v),
                      ),
                    const SizedBox(height: 10),
                    TextField(controller: _section, decoration: const InputDecoration(labelText: 'শাখা (ঐচ্ছিক)', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'ফোন (ঐচ্ছিক)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _code,
                      decoration: const InputDecoration(
                        labelText: 'নিবন্ধন কোড',
                        helperText: 'শিক্ষক/আয়োজক কোড দিলে এখানে লিখুন',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_register ? 'নিবন্ধন করুন' : 'লগইন'),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _register = !_register;
                              _error = null;
                            });
                            if (_register && _classes.isEmpty) _loadClasses();
                          },
                    child: Text(_register ? 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন' : 'নতুন ছাত্র? নিবন্ধন করুন'),
                  ),
                  const Divider(height: 28),
                  ExpansionTile(
                    title: const Text('সার্ভারের ঠিকানা'),
                    subtitle: Text(Api.baseUrl, style: const TextStyle(fontSize: 12)),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      TextField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          helperText: 'আসল ফোনে কম্পিউটারের IP, যেমন http://192.168.0.10:8080',
                          helperMaxLines: 2,
                        ),
                        onSubmitted: (v) async {
                          await Api.setBase(v);
                          if (mounted) {
                            setState(() {});
                            toast(context, 'সংরক্ষিত: ${Api.baseUrl}');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
