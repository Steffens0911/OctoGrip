/// Stub para plataformas não-web. Todos os métodos retornam false/noop.
class PwaInstallService {
  PwaInstallService._();
  static final PwaInstallService instance = PwaInstallService._();

  bool get isInstalled => false;
  bool get canInstallNatively => false;
  bool triggerInstall() => false;
}
