import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';

/// সার্ভার থেকে লাইভ ইভেন্ট (পরীক্ষা তৈরি/প্রকাশ ইত্যাদি). কেটে গেলে নিজে আবার সংযোগ করে.
/// সংযোগ (পুনঃসংযোগসহ) হলে {"type":"connected"} ইভেন্ট দেয়, যাতে স্ক্রিন নতুন করে ডেটা আনে.
class Live {
  Live(this.onEvent);
  final void Function(Map<String, dynamic> ev) onEvent;

  WebSocketChannel? _ch;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _retry;
  bool _stopped = true;
  int _delay = 1;

  void start() {
    _stopped = false;
    _connect();
  }

  void stop() {
    _stopped = true;
    _retry?.cancel();
    _cleanup();
  }

  void _connect() {
    if (_stopped || Api.token == null) return;
    _cleanup();
    try {
      final ch = WebSocketChannel.connect(Uri.parse(Api.wsUrl()));
      _ch = ch;
      ch.ready.then((_) {
        if (_ch == ch && !_stopped) {
          _delay = 1;
          onEvent({'type': 'connected'});
        }
      }).catchError((_) {});
      _sub = ch.stream.listen(
        (m) {
          try {
            final j = jsonDecode(m as String);
            if (j is Map && j['type'] != 'pong') onEvent(Map<String, dynamic>.from(j));
          } catch (_) {}
        },
        onDone: _lost,
        onError: (_) => _lost(),
        cancelOnError: true,
      );
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        try {
          ch.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _lost();
    }
  }

  void _lost() {
    _cleanup();
    if (_stopped) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _delay), _connect);
    _delay = min(_delay * 2, 30);
  }

  void _cleanup() {
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
  }
}

/// Admin/শিক্ষকের পর্দাগুলো লাইভ ইভেন্ট শোনে (Live থেকে এখানে আসে).
class Bus {
  static final StreamController<Map<String, dynamic>> events = StreamController<Map<String, dynamic>>.broadcast();
}
