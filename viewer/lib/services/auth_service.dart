import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:viewer/config/feature_flags.dart';
import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';
import 'package:viewer/services/daily_checkin_service.dart';
import 'package:viewer/services/push_notification_service.dart';
import 'package:viewer/services/student_home_snapshot_store.dart';

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
  bool _randomPartnerShown = false;
  bool _loginNoticeShown = false;
  /// Previne re-entrada concorrente em logout() e impede que ensureLoaded()
  /// recarregue o token do storage enquanto o logout ainda está em progresso.
  bool _loggingOut = false;

  AuthService._();

  String? get token => _token;
  UserModel? get currentUser => _effectiveUser ?? _currentUser;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  bool get isImpersonating => _impersonatedUserId != null;
  String? get impersonatedUserId => _impersonatedUserId;

  static String _normRole(String? r) => (r ?? '').trim().toLowerCase();

  /// Conta que fez login (ignora "Atuar como"). Usa [_currentUser], reidratado em [init] com [getAuthMeAsRealUser] quando há impersonação.
  bool get isRealUserAdmin => _normRole(_currentUser?.role) == 'administrador';

  /// Supervisor real (JWT), ignorando papel efetivo na simulação.
  bool get isRealUserSupervisor => _normRole(_currentUser?.role) == 'supervisor';

  bool get randomPartnerShown => _randomPartnerShown;

  void markRandomPartnerShown() {
    _randomPartnerShown = true;
  }

  bool get loginNoticeShown => _loginNoticeShown;

  void markLoginNoticeShown() {
    _loginNoticeShown = true;
  }

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

  /// Persiste token e utilizador antes de notificar a UI (evita perder sessão se a app fechar logo a seguir ao login).
  Future<void> setLoggedIn(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    _impersonatedUserId = null;
    _effectiveUser = null;
    _randomPartnerShown = false;
    _loginNoticeShown = false;
    await _saveToStorage(token, user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyImpersonate);
    notifyListeners();
    if (kPushNotificationsEnabled) {
      await PushNotificationService.registerTokenIfLoggedIn();
      PushNotificationService.schedulePostLoginPushTokenRetries();
    }
  }

  Future<void> logout({bool notifyInvalidated = false}) async {
    // Guard contra re-entrada: múltiplos 401 concorrentes podem chamar logout()
    // simultaneamente; sem esse flag, ensureLoaded() recarrega o token do
    // storage (não limpo ainda) entre o _token=null e o await _clearStorage(),
    // fazendo isLoggedIn voltar a true e disparando outro logout → loop infinito.
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      _impersonatedUserId = null;
      _effectiveUser = null;
      _token = null;
      _currentUser = null;
      _randomPartnerShown = false;
      _loginNoticeShown = false;
      await _clearStorage();
      await PushNotificationService.unregister();
      await StudentHomeSnapshotStore.clearAll();
      await DailyCheckinService.instance.clear();
      ApiService().invalidateCache();
      notifyListeners();
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> setImpersonating(String? userId) async {
    if (userId == null) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonate);
      // Ao sair da simulação, limpamos o cache para que as próximas
      // chamadas de API reflitam imediatamente o usuário real.
      ApiService().invalidateCache();
      notifyListeners();
      return;
    }
    _impersonatedUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImpersonate, userId);
    try {
      if (_token != null) {
        try {
          final real = await ApiService().getAuthMeAsRealUser();
          _currentUser = real;
          await _saveToStorage(_token!, real);
        } catch (_) {}
      }
      final user = await ApiService().getAuthMe();
      _effectiveUser = user;
    } catch (_) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      await prefs.remove(_keyImpersonate);
      rethrow;
    }
    // Ao começar a atuar como outro usuário, limpamos o cache para que
    // missões, XP, contadores etc. sejam recarregados para o perfil escolhido.
    ApiService().invalidateCache();
    notifyListeners();
  }

  String? get authHeader => _token != null ? 'Bearer $_token' : null;

  Future<void> ensureLoaded() async {
    // Não recarrega o token durante logout: _clearStorage() pode ainda não ter
    // terminado, e _loadFromStorage() leria o token antigo do storage, fazendo
    // isLoggedIn voltar a true e disparando novo logout → loop infinito.
    if (_token == null && !_loggingOut) await _loadFromStorage();
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

  /// Atualiza o usuário atual (me) a partir da API. Após PATCH /auth/me, use para refletir gallery_visible etc.
  Future<void> refreshMe() async {
    if (_token == null) return;
    try {
      final user = await ApiService().getAuthMe();
      if (_impersonatedUserId != null) {
        _effectiveUser = user;
      } else {
        _currentUser = user;
        await _saveToStorage(_token!, user);
      }
      notifyListeners();
    } catch (_) {
      rethrow;
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

  /// Aluno efetivo com conta congelada (modo leitura para treinos/pontos).
  bool get isEffectiveStudentFrozen =>
      isStudent() && (currentUser?.accountFrozen == true);
}
