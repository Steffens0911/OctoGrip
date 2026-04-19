/// Implementação em plataformas que não são web (nunca chamada com `kIsWeb`).
Future<String> webNotificationPermissionResult() async {
  throw UnsupportedError('Apenas Web');
}
