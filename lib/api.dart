import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => message;
}

/// সার্ভারের REST API. টোকেন ও সার্ভার ঠিকানা ফোনে সংরক্ষিত থাকে.
class Api {
  /// Android emulator থেকে কম্পিউটারের localhost = 10.0.2.2. আসল ফোনে কম্পিউটারের IP দিতে হবে.
  static String baseUrl = 'http://192.168.137.1:8080';
  static String? token;
  static Map<String, dynamic>? user;

  /// মেয়াদ শেষ/অবৈধ টোকেনে (৪০১) ডাকা হয়
  static void Function()? onExpired;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      baseUrl = p.getString('baseUrl') ?? baseUrl;
      token = p.getString('token');
      final u = p.getString('user');
      if (u != null) user = jsonDecode(u) as Map<String, dynamic>;
    } catch (_) {}
  }

  static Future<void> setBase(String url) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    baseUrl = u;
    try {
      (await SharedPreferences.getInstance()).setString('baseUrl', u);
    } catch (_) {}
  }

  static Future<void> _saveSession(Map<String, dynamic> res) async {
    token = res['token'] as String;
    user = Map<String, dynamic>.from(res['user'] as Map);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('token', token!);
      await p.setString('user', jsonEncode(user));
    } catch (_) {}
  }

  static Future<void> logout() async {
    token = null;
    user = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('token');
      await p.remove('user');
    } catch (_) {}
  }

  static bool get loggedIn => token != null && user != null;

  static String wsUrl() {
    final ws = baseUrl.startsWith('https://') ? 'wss://${baseUrl.substring(8)}' : 'ws://${baseUrl.substring(7)}';
    return '$ws/ws?token=${Uri.encodeQueryComponent(token ?? '')}';
  }

  static Future<dynamic> _send(String method, String path, {Object? body, bool auth = true}) async {
    final http.Request req;
    try {
      req = http.Request(method, Uri.parse('$baseUrl$path'));
    } on FormatException {
      throw ApiError(0, 'সার্ভারের ঠিকানা ঠিক নয়');
    }
    req.headers['Content-Type'] = 'application/json; charset=utf-8';
    if (auth && token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    http.StreamedResponse res;
    try {
      res = await req.send().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiError(0, 'সার্ভার সাড়া দিচ্ছে না');
    } on FormatException {
      throw ApiError(0, 'সার্ভারের ঠিকানা ঠিক নয়');
    } on Exception {
      throw ApiError(0, 'সার্ভারে পৌঁছানো যাচ্ছে না (ঠিকানা ও Wi-Fi দেখুন)');
    }
    final text = await res.stream.bytesToString();
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && auth) {
      onExpired?.call();
    }
    final msg = (data is Map && data['error'] != null) ? data['error'].toString() : 'ত্রুটি (${res.statusCode})';
    throw ApiError(res.statusCode, msg);
  }

  // ---------- auth ----------
  static Future<Map<String, dynamic>> login(String roll, String password) async {
    final r = await _send('POST', '/api/auth/login', body: {'roll': roll, 'password': password}, auth: false);
    final m = Map<String, dynamic>.from(r as Map);
    await _saveSession(m);
    return m;
  }

  static Future<Map<String, dynamic>> register(Map<String, dynamic> body) async {
    final r = await _send('POST', '/api/auth/register', body: body, auth: false);
    final m = Map<String, dynamic>.from(r as Map);
    await _saveSession(m);
    return m;
  }

  static Future<List<Map<String, dynamic>>> publicClasses() async {
    final r = await _send('GET', '/api/auth/classes', auth: false);
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------- ছাত্র ----------
  static Future<List<Map<String, dynamic>>> exams() async {
    final r = await _send('GET', '/api/exams');
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> start(int examId) async =>
      Map<String, dynamic>.from(await _send('POST', '/api/exams/$examId/start') as Map);

  static Future<void> saveAnswers(int attemptId, List<int> answers) =>
      _send('PUT', '/api/attempts/$attemptId/answers', body: {'answers': answers});

  static Future<Map<String, dynamic>> submit(int attemptId, List<int> answers) async =>
      Map<String, dynamic>.from(await _send('POST', '/api/attempts/$attemptId/submit', body: {'answers': answers}) as Map);

  static Future<Map<String, dynamic>> result(int examId) async =>
      Map<String, dynamic>.from(await _send('GET', '/api/results/$examId') as Map);

  static Future<Map<String, dynamic>> leaderboard(int examId) async =>
      Map<String, dynamic>.from(await _send('GET', '/api/exams/$examId/leaderboard') as Map);

  static Future<void> changePassword(String oldPw, String newPw) =>
      _send('POST', '/api/me/password', body: {'oldPassword': oldPw, 'newPassword': newPw});
  static Future<void> resetPassword(int userId, String newPw) =>
      _send('PUT', '/api/admin/users/$userId/password', body: {'newPassword': newPw});

  // ---------- Admin / শিক্ষক ----------
  static List<Map<String, dynamic>> _list(dynamic r) => (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  static Map<String, dynamic> _map(dynamic r) => Map<String, dynamic>.from(r as Map);

  static Future<List<Map<String, dynamic>>> adminExams() async => _list(await _send('GET', '/api/admin/exams'));
  static Future<Map<String, dynamic>> adminExam(int id) async => _map(await _send('GET', '/api/admin/exams/$id'));
  static Future<Map<String, dynamic>> adminResults(int id) async => _map(await _send('GET', '/api/admin/exams/$id/results'));
  static Future<void> createExam(Map<String, dynamic> body) => _send('POST', '/api/admin/exams', body: body);
  static Future<void> updateExam(int id, Map<String, dynamic> body) => _send('PUT', '/api/admin/exams/$id', body: body);
  static Future<void> setPublished(int id, bool v) => _send('POST', '/api/admin/exams/$id/${v ? 'publish' : 'unpublish'}');
  static Future<void> deleteExam(int id) => _send('DELETE', '/api/admin/exams/$id');
  static Future<List<Map<String, dynamic>>> adminClasses() async => _list(await _send('GET', '/api/admin/classes'));
  static Future<void> addClass(String name) => _send('POST', '/api/admin/classes', body: {'name': name, 'sections': ''});
  static Future<void> addSection(int classId, String name) => _send('POST', '/api/admin/classes/$classId/sections', body: {'name': name});
  static Future<List<Map<String, dynamic>>> adminStudents() async => _list(await _send('GET', '/api/admin/students'));
  static Future<Map<String, dynamic>> studentReport(int id) async => _map(await _send('GET', '/api/admin/students/$id/report'));
  static Future<void> enroll(int studentId, int classId, String section) =>
      _send('PUT', '/api/admin/students/$studentId/enroll', body: {'classId': classId, 'section': section});
  static Future<List<Map<String, dynamic>>> teachers() async => _list(await _send('GET', '/api/admin/teachers'));
  static Future<void> addTeacher(Map<String, dynamic> body) => _send('POST', '/api/admin/teachers', body: body);
  static Future<void> setTeacherClasses(int id, List<int> classIds) =>
      _send('PUT', '/api/admin/teachers/$id/classes', body: {'classIds': classIds});
  static Future<void> deleteTeacher(int id) => _send('DELETE', '/api/admin/teachers/$id');

  // ---------- Auto-discovery ----------
  /// Local network scan করে Live MCQ server খুঁজে বের করে।
  /// পাওয়া গেলে URL return করে, না পেলে null।
  static Future<String?> discover() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

          // সব IP একসাথে parallel-এ চেক করে (দ্রুত)
          final futures = List.generate(254, (i) async {
            final ip = '$subnet.${i + 1}';
            try {
              final res = await http
                  .get(Uri.parse('http://$ip:8080/api/health'))
                  .timeout(const Duration(milliseconds: 600));
              if (res.statusCode == 200) return 'http://$ip:8080';
            } catch (_) {}
            return null;
          });

          final results = await Future.wait(futures);
          final found = results.whereType<String>().firstOrNull;
          if (found != null) return found;
        }
      }
    } catch (_) {}
    return null;
  }
}
