// lib/services/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthService extends ChangeNotifier {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final String baseUrl = AppConfig.baseUrl; // e.g. https://taskapi-1-zwcj.onrender.com

  // public state
  bool initializing = true;
  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  String? accessToken;
  String? refreshToken;
  Map<String, dynamic>? me;

  // network timeout
  Duration _timeout = const Duration(seconds: 30);

  // Simple guard to avoid multiple concurrent refresh attempts
  Completer<bool>? _refreshCompleter;

  AuthService();

  // ---------- Debug helpers ----------
  void _debugDumpTokens(String where) {
    try {
      debugPrint('[AuthService] $where: access=${accessToken != null} refresh=${refreshToken != null} (inMemory)');
    } catch (e) {
      debugPrint('[AuthService] _debugDumpTokens error: $e');
    }
  }

  Future<void> debugReadStoredKeys() async {
    try {
      final a = await storage.read(key: "access");
      final r = await storage.read(key: "refresh");
      debugPrint('[AuthService] storage read: accessPresent=${a != null} refreshPresent=${r != null}');
      debugPrint('[AuthService] storage lengths: access=${a?.length ?? 0} refresh=${r?.length ?? 0}');
      if (a != null) debugPrint('[AuthService] storage access prefix: ${a.substring(0, a.length > 16 ? 16 : a.length)}...');
    } catch (e) {
      debugPrint('[AuthService] debugReadStoredKeys error: $e');
    }
  }

  // ---------- Initialization ----------
  Future<void> init() async {
    initializing = true;
    notifyListeners();

    try {
      // read from storage into memory
      try {
        accessToken = await storage.read(key: "access");
        refreshToken = await storage.read(key: "refresh");
        debugPrint('[AuthService] init: read storage done');
      } catch (e) {
        debugPrint('[AuthService] init: storage read failed: $e');
      }

      _debugDumpTokens('init(read)');

      if (accessToken != null) {
        // Try to validate access token by fetching profile (no auto-refresh on this call)
        final ok = await tryFetchProfile(autoRefresh: false);
        if (ok) {
          _loggedIn = true;
        } else {
          // Try refreshing tokens once
          final refreshed = await _refreshToken();
          if (refreshed) {
            final ok2 = await tryFetchProfile(autoRefresh: false);
            _loggedIn = ok2;
          } else {
            await _clearTokensLocal();
            _loggedIn = false;
          }
        }
      } else if (refreshToken != null) {
        // No access but have refresh -> try exchange
        final refreshed = await _refreshToken();
        if (refreshed) {
          final ok = await tryFetchProfile(autoRefresh: false);
          _loggedIn = ok;
        } else {
          _loggedIn = false;
        }
      } else {
        _loggedIn = false;
      }
    } catch (e) {
      debugPrint('[AuthService] init error: $e');
      _loggedIn = false;
    } finally {
      initializing = false;
      _debugDumpTokens('init done');
      debugPrint('[AuthService] init: loggedIn=$_loggedIn');
      notifyListeners();
    }
  }

  /// Fetch current user profile. Returns true on HTTP 200 and sets `me`.
  /// If autoRefresh==true the method will attempt to refresh tokens on 401 once.
  Future<bool> tryFetchProfile({bool autoRefresh = true}) async {
    final token = accessToken ?? await storage.read(key: "access");
    if (token == null) return false;

    try {
      final res = await http
          .get(
        Uri.parse("$baseUrl/auth/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      )
          .timeout(const Duration(seconds: 8));

      debugPrint('[AuthService] tryFetchProfile status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map) {
          me = Map<String, dynamic>.from(data);
        }
        _loggedIn = true;
        notifyListeners();
        return true;
      }

      if (res.statusCode == 401 && autoRefresh) {
        debugPrint('[AuthService] tryFetchProfile: 401, attempting refresh');
        final refreshed = await _refreshToken();
        if (!refreshed) return false;
        // try again once
        return await tryFetchProfile(autoRefresh: false);
      }

      return false;
    } on TimeoutException {
      debugPrint('[AuthService] tryFetchProfile timeout');
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] tryFetchProfile network error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] tryFetchProfile error: $e');
      return false;
    }
  }

  // ---------- Token refresh ----------
  Future<bool> _refreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();

    final refresh = refreshToken ?? await storage.read(key: "refresh");
    if (refresh == null) {
      debugPrint('[AuthService] _refreshToken: no refresh token available');
      _refreshCompleter!.complete(false);
      _refreshCompleter = null;
      return false;
    }

    debugPrint('[AuthService] attempting refresh (haveRefresh=true)');

    http.Response? res;
    try {
      res = await http
          .post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refreshToken": refresh}),
      )
          .timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] refresh status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newAccess = data["accessToken"] ?? data["access"];
        final newRefresh = data["refreshToken"] ?? data["refresh"];

        try {
          if (newAccess != null) {
            accessToken = newAccess.toString();
            await storage.write(key: "access", value: accessToken);
          }
          if (newRefresh != null) {
            refreshToken = newRefresh.toString();
            await storage.write(key: "refresh", value: refreshToken);
          }
        } catch (e) {
          debugPrint('[AuthService] refresh: storage write failed: $e');
        }

        _debugDumpTokens('refresh success');
        notifyListeners();
        _refreshCompleter!.complete(true);
        _refreshCompleter = null;
        return true;
      } else {
        debugPrint('[AuthService] refresh failed (status ${res.statusCode})');
        await _clearTokensLocal();
        notifyListeners();
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      }
    } on TimeoutException {
      debugPrint('[AuthService] refresh token timed out');
      _refreshCompleter!.complete(false);
      _refreshCompleter = null;
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] refresh token network error: ${e.message}');
      _refreshCompleter!.complete(false);
      _refreshCompleter = null;
      return false;
    } catch (e) {
      debugPrint('[AuthService] refresh token error: $e');
      if (res != null) debugPrint('[AuthService] refresh last response: ${res.body}');
      _refreshCompleter!.complete(false);
      _refreshCompleter = null;
      return false;
    }
  }

  // ---------- Ensure access token ----------
  Future<String?> ensureAccessToken() async {
    if (accessToken != null) return accessToken;

    try {
      final stored = await storage.read(key: "access");
      if (stored != null) {
        accessToken = stored;
        _debugDumpTokens('ensureAccessToken loaded from storage');
        return accessToken;
      }
    } catch (e) {
      debugPrint('[AuthService] ensureAccessToken storage read failed: $e');
    }

    // attempt refresh
    final refreshed = await _refreshToken();
    if (refreshed) return accessToken;
    return null;
  }

  Future<String?> getAccessToken() async => accessToken ?? await storage.read(key: "access");
  Future<String?> getRefreshToken() async => refreshToken ?? await storage.read(key: "refresh");

  // ---------- Auth API: login/register/refresh/logout ----------
  Future<bool> login(String email, String password) async {
    final urlPath = "/auth/login";
    try {
      final res = await http
          .post(
        Uri.parse("$baseUrl$urlPath"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      )
          .timeout(_timeout);

      debugPrint('[AuthService] login status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final a = data["accessToken"] ?? data["access"];
        final r = data["refreshToken"] ?? data["refresh"];

        try {
          if (a != null) {
            accessToken = a.toString();
            await storage.write(key: "access", value: accessToken);
          }
          if (r != null) {
            refreshToken = r.toString();
            await storage.write(key: "refresh", value: refreshToken);
          }
        } catch (e) {
          debugPrint('[AuthService] login: storage write failed: $e');
        }

        _debugDumpTokens('after login (saved)');
        debugPrint('[AuthService] login success; access preview=${accessToken?.substring(0, 16)}...');
        _loggedIn = true;
        notifyListeners();
        await tryFetchProfile(autoRefresh: false);
        return true;
      }

      final parsedMsg = _parseErrorFromResponse(res);
      debugPrint('[AuthService] login failed: $parsedMsg');
      return false;
    } on TimeoutException {
      debugPrint('[AuthService] Login request timed out after ${_timeout.inSeconds}s');
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] Network error during login: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Login error: $e');
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    final urlPath = "/auth/register";
    try {
      final res = await http
          .post(
        Uri.parse("$baseUrl$urlPath"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "email": email, "password": password}),
      )
          .timeout(_timeout);

      debugPrint('[AuthService] register status=${res.statusCode} body=${res.body}');

      if (res.statusCode == 201 || res.statusCode == 200) {
        // Try to capture tokens if returned
        try {
          final data = jsonDecode(res.body);
          final a = data["accessToken"] ?? data["access"];
          final r = data["refreshToken"] ?? data["refresh"];
          if (a != null) {
            accessToken = a.toString();
            await storage.write(key: "access", value: accessToken);
          }
          if (r != null) {
            refreshToken = r.toString();
            await storage.write(key: "refresh", value: refreshToken);
          }
        } catch (_) {}

        _debugDumpTokens('after register');
        debugPrint('[AuthService] register finished; loggedIn=$_loggedIn');

        // If the server didn't return tokens, attempt to login automatically
        if (accessToken == null) {
          final loginOk = await login(email, password);
          if (!loginOk) {
            debugPrint('[AuthService] register: fallback login failed');
            return false;
          }
        } else {
          _loggedIn = true;
          notifyListeners();
          await tryFetchProfile(autoRefresh: false);
        }

        return true;
      }

      final parsedMsg = _parseErrorFromResponse(res);
      debugPrint('[AuthService] register failed: $parsedMsg');
      return false;
    } on TimeoutException {
      debugPrint('[AuthService] Registration request timed out after ${_timeout.inSeconds}s');
      return false;
    } on SocketException catch (e) {
      debugPrint('[AuthService] Network error during registration: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] Registration error: $e');
      return false;
    }
  }

  String _parseErrorFromResponse(http.Response res) {
    try {
      if (res.body.trimLeft().startsWith('<')) {
        return "Server returned non-JSON response (HTML). Check API baseUrl and that backend is running. HTTP ${res.statusCode}";
      }
      if (res.body.isEmpty) return "Request failed (empty response, HTTP ${res.statusCode})";

      final parsed = jsonDecode(res.body);

      if (parsed is String && parsed.isNotEmpty) return parsed;

      if (parsed is Map) {
        if (parsed.containsKey("message") && parsed["message"] != null) return parsed["message"].toString();
        if (parsed.containsKey("error") && parsed["error"] != null) return parsed["error"].toString();

        if (parsed.containsKey("errors") && parsed["errors"] != null) {
          final errs = parsed["errors"];
          if (errs is List) return errs.map((e) => e.toString()).join("; ");
          if (errs is Map) {
            final parts = <String>[];
            errs.forEach((k, v) {
              if (v is List) parts.add("$k: ${v.map((e) => e.toString()).join(', ')}");
              else parts.add("$k: ${v.toString()}");
            });
            if (parts.isNotEmpty) return parts.join(" • ");
          }
        }

        final validationParts = <String>[];
        for (final entry in parsed.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is List) {
            validationParts.add("$key: ${val.map((e) => e.toString()).join(', ')}");
          } else if (val is String && val.isNotEmpty) {
            validationParts.add("$key: $val");
          }
        }
        if (validationParts.isNotEmpty) return validationParts.join(" • ");
      }

      return "Request failed: ${res.body}";
    } catch (e) {
      debugPrint("[AuthService] parse error response failed: $e -- raw: ${res.body}");
      return "Request failed (HTTP ${res.statusCode})";
    }
  }

  Future<void> logout() async {
    final refresh = refreshToken ?? await storage.read(key: "refresh");

    try {
      if (refresh != null) {
        await http
            .post(
          Uri.parse("$baseUrl/auth/logout"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"refreshToken": refresh}),
        )
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // ignore network errors
    }

    await _clearTokensLocal();
    _loggedIn = false;
    me = null;
    notifyListeners();
    debugPrint('[AuthService] logged out (local cleared)');
  }

  Future<void> _clearTokensLocal() async {
    accessToken = null;
    refreshToken = null;
    try {
      await storage.delete(key: "access");
      await storage.delete(key: "refresh");
      debugPrint('[AuthService] cleared tokens from storage');
    } catch (e) {
      debugPrint('[AuthService] failed to clear tokens: $e');
    }
  }
}
