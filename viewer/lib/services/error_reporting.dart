import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:viewer/services/app_update_service.dart';

/// DSN do projeto Sentry do app (diferente do `octogrip-api`), vinda do build:
/// `--dart-define=SENTRY_DSN=...` (build-mobile.yml → tool/prepare_mobile_build.py).
/// Vazia = Sentry desligado (desenvolvimento local, web).
const String _kSentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

bool get isErrorReportingEnabled => _kSentryDsn.isNotEmpty;

/// Inicia o Sentry (quando configurado) e então chama [appRunner].
///
/// Cada evento leva a versão do app como `release`, para separar o erro de uma
/// versão que ainda está nos celulares do erro de uma versão já corrigida.
Future<void> runWithErrorReporting(void Function() appRunner) async {
  _installFriendlyErrorWidget();
  if (!isErrorReportingEnabled) {
    appRunner();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _kSentryDsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      final version = AppClientInfo.version;
      if (version != null) options.release = 'br.com.octogrip.app@$version';
      // Sem PII: LGPD (alunos podem ser menores). Nada de IP, e-mail ou nome.
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0.0;
    },
    appRunner: () {
      Sentry.configureScope((scope) {
        final platform = AppClientInfo.platform;
        if (platform != null) scope.setTag('app.platform', platform);
      });
      appRunner();
    },
  );
}

/// Em release, uma tela que falha mostra uma mensagem em vez do bloco cinza.
void _installFriendlyErrorWidget() {
  if (!kReleaseMode) return;
  ErrorWidget.builder = (details) => const Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Algo deu errado ao mostrar esta parte da tela.\n'
              'Volte e tente de novo.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
