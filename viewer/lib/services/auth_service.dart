import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:viewer/models/user.dart';
import 'package:viewer/services/api_service.dart';

const _keyToken = 'auth_token';
const _keyUser = 'auth_user';
const _keyImpersonate = 'impersonate_user_id';

/// Serviço de autenticação: login, token e usuário atual.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  String? _token;
  UserModel? _currentUser;
  String? _impersonatedUserId;
  UserModel? _effectiveUser;

  /// Chamado quando a sessão é encerrada por 401 (token inválido/expirado). Definir em AuthGate para atualizar a UI.
  void Function()? onSessionInvalidated;

  /// Chamado quando entra/sai da simulação (atuar como). Definir na shell para redesenhar.
  void Function()? onImpersonationChange;

  AuthService._();

  String? get token => _token;
  /// Usuário efetivo: simulado se em impersonation, senão o logado.
  UserModel? get currentUser => _effectiveUser ?? _currentUser;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  bool get isImpersonating => _impersonatedUserId != null;
  String? get impersonatedUserId => _impersonatedUserId;

  /// True se o usuário logado (real) é admin. Use para exibir "Atuar como" mesmo quando simulando outro usuário.
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

  /// Inicializa o serviço a partir do storage. Chamar no startup.
  Future<void> init() async {
    await _loadFromStorage();
  }

  /// Define token e usuário após login bem-sucedido.
  void setLoggedIn(String token, UserModel user) {
    _token = token;
    _currentUser = user;
    _saveToStorage(token, user);
  }

  /// Remove sessão (logout). Se [notifyInvalidated] for true, chama [onSessionInvalidated] após limpar.
  /// Também limpa a simulação (impersonation).
  Future<void> logout({bool notifyInvalidated = false}) async {
    _impersonatedUserId = null;
    _effectiveUser = null;
    _token = null;
    _currentUser = null;
    await _clearStorage();
    if (notifyInvalidated) onSessionInvalidated?.call();
  }

  /// Define ou limpa a simulação (atuar como outro usuário). Apenas admin.
  /// [userId] null = sair da simulação; senão = id do usuário alvo.
  Future<void> setImpersonating(String? userId) async {
    if (userId == null) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonate);
      onImpersonationChange?.call();
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
    onImpersonationChange?.call();
  }

  /// Retorna o header Authorization para requisições autenticadas.
  String? get authHeader => _token != null ? 'Bearer $_token' : null;

  /// Recarrega usuário do storage (útil após init). Não chama getAuthMe aqui para evitar recursão.
  Future<void> ensureLoaded() async {
    if (_token == null) await _loadFromStorage();
  }

  /// Restaura _effectiveUser quando a app abre com impersonation persistida. Chamar da UI (ex.: MainShell) em post-frame, não de ensureLoaded.
  Future<void> restoreImpersonation() async {
    if (_impersonatedUserId == null || _effectiveUser != null || _token == null) return;
    try {
      _effectiveUser = await ApiService().getAuthMe();
      onImpersonationChange?.call();
    } catch (_) {
      _impersonatedUserId = null;
      _effectiveUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyImpersonate);
    }
  }

  // ---------- Helpers de Role (usam usuário efetivo: simulado ou real) ----------

  /// Verifica se o usuário é administrador.
  bool isAdmin() => currentUser?.role == 'administrador';

  /// Verifica se o usuário é gerente de academia.
  bool isManager() => currentUser?.role == 'gerente_academia';

  /// Verifica se o usuário é professor.
  bool isProfessor() => currentUser?.role == 'professor';

  /// Verifica se o usuário é aluno.
  bool isStudent() => currentUser?.role == 'aluno';

  /// Verifica se o usuário é supervisor.
  bool isSupervisor() => currentUser?.role == 'supervisor';

  /// Verifica se o usuário pode acessar a seção de administração.
  bool canAccessAdmin() => isAdmin();

  /// Verifica se o usuário pode acessar o painel de academia.
  bool canAccessAcademyPanel() =>
      isAdmin() || isManager() || isProfessor() || isSupervisor();

  /// Verifica se o usuário pode editar recursos (não supervisor).
  bool canEditResources() => !isSupervisor() && canAccessAcademyPanel();
}
