// lib/services/task_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class TaskService extends ChangeNotifier {
  final String baseUrl = AppConfig.baseUrl; // e.g. https://taskapi-1-zwcj.onrender.com

  AuthService? _auth;
  List<dynamic> tasks = [];
  bool isLoading = false;

  // call from ChangeNotifierProxyProvider.update to inject/refresh auth
  void updateAuth(AuthService auth) {
    _auth = auth;
    debugPrint('[TaskService] updateAuth: loggedIn=${auth.loggedIn}');
    if (_auth?.loggedIn == true) {
      fetchTasks();
    } else {
      tasks = [];
      notifyListeners();
    }
  }

  Future<String?> _getValidAccessToken() async {
    if (_auth == null) return null;
    try {
      final token = await _auth!.ensureAccessToken();
      return token;
    } catch (e) {
      debugPrint('[TaskService] _getValidAccessToken error: $e');
      return null;
    }
  }

  // Helper to parse response for friendly messages
  String _extractServerMessage(http.Response res) {
    final body = res.body ?? '';
    try {
      if (body.trimLeft().startsWith('<')) {
        return 'Server returned HTML (HTTP ${res.statusCode})';
      }
      final parsed = jsonDecode(body);
      if (parsed is Map) {
        if (parsed.containsKey('message')) return parsed['message'].toString();
        if (parsed.containsKey('error')) return parsed['error'].toString();
      }
      return body;
    } catch (e) {
      return 'Failed to parse server response (HTTP ${res.statusCode})';
    }
  }

  Future<void> fetchTasks() async {
    isLoading = true;
    notifyListeners();

    final token = await _getValidAccessToken();
    if (token == null) {
      isLoading = false;
      notifyListeners();
      debugPrint('[TaskService] fetchTasks: no valid access token (user not authenticated)');
      // Do NOT throw here; just clear tasks and exit gracefully.
      tasks = [];
      // Optionally, request a UI-level logout:
      // await _auth?.logout();
      return;
    }

    final uri = Uri.parse("$baseUrl/tasks");
    debugPrint('[TaskService] GET $uri with token present');

    http.Response res;
    try {
      res = await http.get(uri, headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      isLoading = false;
      notifyListeners();
      debugPrint('[TaskService] fetchTasks timeout');
      return;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('[TaskService] fetchTasks network error: $e');
      return;
    }

    debugPrint('[TaskService] fetchTasks status=${res.statusCode} body=${res.body}');

    if (res.statusCode == 401) {
      // try refresh once (ensureAccessToken may have already refreshed)
      final newToken = await _getValidAccessToken();
      if (newToken != null && newToken != token) {
        // retry with refreshed token
        return fetchTasks();
      } else {
        isLoading = false;
        notifyListeners();
        debugPrint('[TaskService] fetchTasks: unauthorized after refresh');
        // optional: force logout and clear tasks
        await _auth?.logout();
        tasks = [];
        return;
      }
    }

    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body);
        if (data is List) {
          tasks = data;
        } else {
          tasks = [];
        }
      } catch (e) {
        debugPrint('[TaskService] fetchTasks parse error: $e');
        tasks = [];
      }
      isLoading = false;
      notifyListeners();
      return;
    }

    debugPrint('[TaskService] fetchTasks unexpected HTTP ${res.statusCode}');
    isLoading = false;
    notifyListeners();
    tasks = [];
  }


  /// Add a task.
  Future<bool> addTask(
      String title,
      String description,
      DateTime startDate,
      DateTime endDate,
      String status,
      ) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

    final payload = {
      "title": title,
      "description": description,
      "startDate": startDate.toIso8601String(),
      "endDate": endDate.toIso8601String(),
      "status": status,
    };

    final uri = Uri.parse("$baseUrl/tasks");
    debugPrint('[TaskService] POST $uri payload=${jsonEncode(payload)}');

    try {
      final res = await http
          .post(uri,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      debugPrint('[TaskService] addTask status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 401) {
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return addTask(title, description, startDate, endDate, status);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchTasks();
        return true;
      }

      // log server error message
      final msg = _extractServerMessage(res);
      debugPrint('[TaskService] addTask failed: $msg');
      return false;
    } on TimeoutException {
      debugPrint('[TaskService] addTask timeout');
      return false;
    } catch (e) {
      debugPrint('[TaskService] addTask error: $e');
      return false;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

    final uri = Uri.parse("$baseUrl/tasks/$id");
    debugPrint('[TaskService] PUT $uri updates=${jsonEncode(updates)}');

    try {
      final res = await http
          .put(uri,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode(updates))
          .timeout(const Duration(seconds: 10));

      debugPrint('[TaskService] updateTask status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 401) {
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return updateTask(id, updates);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      return false;
    } on TimeoutException {
      debugPrint('[TaskService] updateTask timeout');
      return false;
    } catch (e) {
      debugPrint('[TaskService] updateTask error: $e');
      return false;
    }
  }

  Future<bool> updateTaskStatus(String id, String status) async {
    return updateTask(id, {"status": status});
  }

  Future<bool> deleteTask(String id) async {
    final token = await _getValidAccessToken();
    if (token == null) {
      await _auth?.logout();
      return false;
    }

    final uri = Uri.parse("$baseUrl/tasks/$id");
    debugPrint('[TaskService] DELETE $uri');

    try {
      final res = await http
          .delete(uri, headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      })
          .timeout(const Duration(seconds: 10));

      debugPrint('[TaskService] deleteTask status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 401) {
        final refreshedToken = await _getValidAccessToken();
        if (refreshedToken != null && refreshedToken != token) {
          return deleteTask(id);
        }
        await _auth?.logout();
        return false;
      }

      if (res.statusCode == 200) {
        await fetchTasks();
        return true;
      }
      return false;
    } on TimeoutException {
      debugPrint('[TaskService] deleteTask timeout');
      return false;
    } catch (e) {
      debugPrint('[TaskService] deleteTask error: $e');
      return false;
    }
  }
}
