// lib/services/note_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class NoteService extends ChangeNotifier {
  final String baseUrl = AppConfig.baseUrl; // e.g. https://taskapi-1-zwcj.onrender.com
  AuthService? _auth;
  List<Map<String, dynamic>> notes = [];
  bool loading = false;
  String search = '';
  bool onlyPinned = false;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (_auth?.loggedIn == true) {
      fetchNotes();
    } else {
      notes = [];
      notifyListeners();
    }
  }

  Future<String?> _token() async {
    if (_auth == null) return null;
    return await _auth!.ensureAccessToken();
  }

  Uri _uri([String path = '']) => Uri.parse("$baseUrl/notes$path");

  void setSearch(String s) {
    search = s;
    notifyListeners();
    // optional: debounce / search server side. For now filter client side.
  }

  void togglePinnedFilter() {
    onlyPinned = !onlyPinned;
    notifyListeners();
  }

  Future<void> fetchNotes() async {
    loading = true;
    notifyListeners();
    final token = await _token();
    if (token == null) {
      loading = false;
      notifyListeners();
      return;
    }

    try {
      final res = await http.get(_uri(), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          notes = List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e)));
        } else {
          notes = [];
        }
      } else if (res.statusCode == 401) {
        // try refresh once via ensureAccessToken in _token()
        final newToken = await _token();
        if (newToken != null && newToken != token) {
          await fetchNotes();
        } else {
          // unauthorized
        }
      } else {
        if (kDebugMode) debugPrint('[NoteService] fetchNotes status=${res.statusCode} body=${res.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NoteService] fetchNotes error: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createNote({required String title, required String content, bool pinned = false, List<String>? tags}) async {
    final token = await _token();
    if (token == null) return false;
    final payload = {
      'title': title,
      'content': content,
      'pinned': pinned,
      'tags': tags ?? [],
    };

    try {
      final res = await http.post(_uri(),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 201 || res.statusCode == 200) {
        await fetchNotes();
        return true;
      } else {
        if (kDebugMode) debugPrint('[NoteService] createNote failed: ${res.statusCode} ${res.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NoteService] createNote error: $e');
      return false;
    }
  }

  Future<bool> updateNote(String id, Map<String, dynamic> updates) async {
    final token = await _token();
    if (token == null) return false;
    try {
      final res = await http.put(_uri('/$id'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(updates)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        await fetchNotes();
        return true;
      } else {
        if (kDebugMode) debugPrint('[NoteService] updateNote failed: ${res.statusCode} ${res.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NoteService] updateNote error: $e');
      return false;
    }
  }

  Future<bool> deleteNote(String id) async {
    final token = await _token();
    if (token == null) return false;
    try {
      final res = await http.delete(_uri('/$id'), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        notes.removeWhere((n) => n['_id'] == id || n['id'] == id);
        notifyListeners();
        return true;
      } else {
        if (kDebugMode) debugPrint('[NoteService] deleteNote failed: ${res.statusCode} ${res.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[NoteService] deleteNote error: $e');
      return false;
    }
  }

  // Client-side filtered list (search + pinned)
  List<Map<String, dynamic>> get filtered {
    var list = List<Map<String, dynamic>>.from(notes);
    if (onlyPinned) list = list.where((n) => n['pinned'] == true).toList();
    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list.where((n) {
        final t = (n['title'] ?? '').toString().toLowerCase();
        final c = (n['content'] ?? '').toString().toLowerCase();
        return t.contains(q) || c.contains(q) || (n['tags'] ?? []).join(' ').toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }
}
