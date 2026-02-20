import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';

const _keyToken = 'auth_token';
const _keyUser = 'auth_user';
const _keyImpersonate = 'impersonate_user_id';

/// Serviço de autenticação com ChangeNotifier para integração com Provider.
/// Singleton: usar AuthService() ou context.read<AuthService>().
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  String? _token;
  UserModel? _currentUser;
  String? _impersonatedUserId;
  UserModel? _effectiveUser;

  AuthService._();

  String? get token => _token;
  UserModel? get currentUser => _effectiveUser ?? _currentUser;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  bool get isImpersonating => _impersonatedUserId != null;
  String? get impersonatedUserId => _impersonatedUserId;

  bool get isRealUserAdmin => _currentUser?.role == 'administrador';

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _impersonatedUserId = prefs.getString(_keyImpersonate);
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _currentUser = null;
      }
    } else {
      _currentUser = null;
    }
    _effectiveUser = null;
  }

  Future<void> _saveToStorage(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyImpersonate);
  }

  Future<void> init() async {
    await _loadFromStorage();
  }

  void setLoggedIn(String token, UserModel user) {
    _token = token;
    _currentUser = user;
    _saveToStorage(token, user);
    notifyListeners();
  }

  Future<void> logout({bool notifyInvalidated = false}) async {
    _impersonatedUserId = null;
    _effectiveUser = null;
    _token = null;
    _currentUser = null;
    await _clearStorage();
    notifyListeners();
  }

  Future<void> setImpersonating(String? userId) async {
    if (userId == null) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonate);
      notifyListeners();
      return;
    }
    _impersonatedUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImpersonate, userId);
    try {
      final user = await ApiService().getAuthMe();
      _effectiveUser = user;
    } catch (_) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      await prefs.remove(_keyImpersonate);
      rethrow;
    }
    notifyListeners();
  }

  String? get authHeader => _token != null ? 'Bearer $_token' : null;

  Future<void> ensureLoaded() async {
    if (_token == null) await _loadFromStorage();
  }

  Future<void> restoreImpersonation() async {
    if (_impersonatedUserId == null || _effectiveUser != null || _token == null) return;
    try {
      _effectiveUser = await ApiService().getAuthMe();
      notifyListeners();
    } catch (_) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonate);
    }
  }

  // ---------- Helpers de Role ----------

  bool isAdmin() => currentUser?.role == 'administrador';
  bool isManager() => currentUser?.role == 'gerente_academia';
  bool isProfessor() => currentUser?.role == 'professor';
  bool isStudent() => currentUser?.role == 'aluno';
  bool isSupervisor() => currentUser?.role == 'supervisor';

  bool canAccessAdmin() => isAdmin();
  bool canAccessAcademyPanel() =>
      isAdmin() || isManager() || isProfessor() || isSupervisor();
  bool canEditResources() => !isSupervisor() && canAccessAcademyPanel();
}
