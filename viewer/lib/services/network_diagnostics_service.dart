import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:viewer/config.dart';
import 'package:viewer/services/api_service.dart';

/// Estado global simples para suporte operacional em produção.
class NetworkDiagnosticsService {
  static String? _lastErrorDetails;
  static DateTime? _lastErrorAt;
  static String? _lastErrorContext;

  static String get apiBase => kApiBaseUrl;

  static String get runtimeEnv =>
      const bool.fromEnvironment('dart.vm.product') ? 'release' : 'debug';

  static String get platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static String get currentOrigin => Uri.base.toString();

  static String? get lastErrorDetails => _lastErrorDetails;
  static DateTime? get lastErrorAt => _lastErrorAt;
  static String? get lastErrorContext => _lastErrorContext;

  static void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
  }) {
    _lastErrorAt = DateTime.now();
    _lastErrorContext = context;
    _lastErrorDetails = _buildErrorDetails(error, stackTrace: stackTrace);
  }

  static String _buildErrorDetails(Object error, {StackTrace? stackTrace}) {
    final b = StringBuffer();
    b.writeln('Tipo: ${error.runtimeType}');

    if (error is ApiException) {
      b.writeln('Categoria: erro HTTP da API');
      b.writeln('Status HTTP: ${error.statusCode}');
      if (error.errorType != null && error.errorType!.isNotEmpty) {
        b.writeln('Error type: ${error.errorType}');
      }
      b.writeln('Mensagem API: ${error.message}');
    } else if (error is TimeoutException) {
      b.writeln('Categoria: timeout');
      b.writeln('Mensagem: ${error.message ?? 'sem detalhe'}');
    } else {
      b.writeln('Categoria: erro de rede/cliente');
      b.writeln('Mensagem: $error');
    }

    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n');
      if (lines.isNotEmpty) {
        b.writeln('Stack (topo): ${lines.first}');
      }
    }
    return b.toString().trim();
  }
}
