import 'package:flutter/material.dart';

/// ISO লেখা → স্থানীয় সময়; ভুল হলে null
DateTime? parseTime(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  try {
    return DateTime.parse(v).toLocal();
  } catch (_) {
    return null;
  }
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtWhen(DateTime? t) => t == null ? '' : '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';

String fmtClock(int secs) {
  if (secs < 0) secs = 0;
  final h = secs ~/ 3600, m = (secs % 3600) ~/ 60, s = secs % 60;
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<DateTime?> pickDateTime(BuildContext c, DateTime? initial) async {
  final now = DateTime.now();
  final d = await showDatePicker(
    context: c,
    initialDate: initial ?? now,
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 5),
  );
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(initial ?? now));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

Future<bool> confirm(BuildContext c, String title, String body, {String ok = 'হ্যাঁ'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (x) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('না')),
        FilledButton(onPressed: () => Navigator.pop(x, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}
