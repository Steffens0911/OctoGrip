import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:viewer/config.dart';
import 'package:viewer/utils/app_version.dart';

/// Versão e plataforma deste app, enviadas à API em toda requisição.
///
/// Só o app de loja (Android/iOS) se identifica: a web sempre roda a versão mais
/// nova e não deve pagar o preflight CORS extra dos headers customizados.
class AppClientInfo {
  AppClientInfo._();

  static String? _version;
  static String? _platform;

  /// Ex.: `1.3.0+12` (versão + build do pubspec).
  static String? get version => _version;

  /// `android`, `ios` ou `null` (web/desktop).
  static String? get platform => _platform;

  static Future<void> init() async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _platform = 'android';
      case TargetPlatform.iOS:
        _platform = 'ios';
      default:
        return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.buildNumber.isEmpty
          ? info.version
          : '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('[AppClientInfo] versão indisponível: $e');
    }
  }

  /// Headers `X-App-Version` / `X-App-Platform`; vazio na web ou sem versão.
  static Map<String, String> get headers {
    final v = _version;
    final p = _platform;
    if (v == null || p == null) return const {};
    return {'X-App-Version': v, 'X-App-Platform': p};
  }

  @visibleForTesting
  static void setForTesting({String? version, String? platform}) {
    _version = version;
    _platform = platform;
  }
}

enum AppUpdateStatus { none, optional, required }

/// Decide se o app precisa (ou deveria) atualizar.
///
/// Fontes: `GET /app/config` ao abrir/voltar ao app e qualquer resposta 426 da API.
/// O [AppUpdateGate] observa este serviço e bloqueia a tela quando [status] é `required`.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// Revalidar a config ao voltar ao app no máximo a cada 30 min.
  static const Duration _recheckInterval = Duration(minutes: 30);

  AppUpdateStatus _status = AppUpdateStatus.none;
  String? _minVersion;
  String? _latestVersion;
  String? _message;
  String? _storeUrl;
  Map<String, dynamic> _featureFlags = const {};
  bool _optionalDismissed = false;
  DateTime? _lastCheck;
  http.Client _client = http.Client();

  AppUpdateStatus get status => _status;
  String? get minVersion => _minVersion;
  String? get latestVersion => _latestVersion;
  String? get message => _message;
  String? get storeUrl => _storeUrl;

  /// Flags vindas de `/app/config`; ver [isFeatureEnabled].
  Map<String, dynamic> get featureFlags => _featureFlags;

  /// Aviso de "nova versão disponível" visível (não bloqueante e não dispensado).
  bool get showOptionalPrompt =>
      _status == AppUpdateStatus.optional && !_optionalDismissed;

  @visibleForTesting
  void setHttpClientForTesting(http.Client client) => _client = client;

  @visibleForTesting
  void resetForTesting() {
    _status = AppUpdateStatus.none;
    _minVersion = null;
    _latestVersion = null;
    _message = null;
    _storeUrl = null;
    _featureFlags = const {};
    _optionalDismissed = false;
    _lastCheck = null;
    notifyListeners();
  }

  /// Consulta `/app/config`. Sem rede ou com erro, não muda nada: o app nunca
  /// bloqueia por falta de resposta.
  Future<void> checkForUpdate({bool force = false}) async {
    final platform = AppClientInfo.platform;
    if (platform == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastCheck != null &&
        now.difference(_lastCheck!) < _recheckInterval) {
      return;
    }
    _lastCheck = now;
    try {
      final base = kApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
      final uri = Uri.parse('$base/app/config?platform=$platform');
      final response = await _client
          .get(uri, headers: AppClientInfo.headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) applyConfig(body);
    } catch (e) {
      debugPrint('[AppUpdateService] /app/config falhou: $e');
    }
  }

  @visibleForTesting
  void applyConfig(Map<String, dynamic> config) {
    _minVersion = config['min_version'] as String?;
    _latestVersion = config['latest_version'] as String?;
    _message = config['update_message'] as String?;
    _storeUrl = config['store_url'] as String? ?? _storeUrl;
    final flags = config['feature_flags'];
    _featureFlags = flags is Map<String, dynamic> ? flags : const {};

    final version = AppClientInfo.version;
    if (isAppVersionBelow(version, _minVersion)) {
      _status = AppUpdateStatus.required;
    } else if (isAppVersionBelow(version, _latestVersion)) {
      _status = AppUpdateStatus.optional;
    } else {
      _status = AppUpdateStatus.none;
    }
    notifyListeners();
  }

  /// Chamado pelo cliente HTTP em qualquer resposta 426 da API.
  void handleUpdateRequiredResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final update = decoded['update'];
        if (update is Map<String, dynamic>) {
          _minVersion = update['min_version'] as String? ?? _minVersion;
          _storeUrl = update['store_url'] as String? ?? _storeUrl;
        }
        _message = decoded['detail'] is String
            ? decoded['detail'] as String
            : _message;
      }
    } catch (_) {
      // Corpo inesperado: o bloqueio vale mesmo assim.
    }
    if (_status == AppUpdateStatus.required) return;
    _status = AppUpdateStatus.required;
    notifyListeners();
  }

  void dismissOptional() {
    _optionalDismissed = true;
    notifyListeners();
  }

  /// `true` se a flag está ligada e a versão do app atende `min_app_version` (quando houver).
  bool isFeatureEnabled(String name) {
    final flag = _featureFlags[name];
    if (flag is bool) return flag;
    if (flag is! Map) return false;
    if (flag['enabled'] != true) return false;
    final minApp = flag['min_app_version'];
    return !(minApp is String &&
        isAppVersionBelow(AppClientInfo.version, minApp));
  }

  /// Android: fluxo nativo da Play (atualização imediata). Se não der, abre a loja.
  Future<void> openStore() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          await InAppUpdate.performImmediateUpdate();
          return;
        }
      } catch (e) {
        // App instalado fora da Play (debug, APK manual): cai para o link da loja.
        debugPrint('[AppUpdateService] in_app_update indisponível: $e');
      }
    }
    final url = _storeUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
