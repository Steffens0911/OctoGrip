/// Fachada do serviço PWA — usa implementação web ou stub conforme a plataforma.
export 'pwa_install_service_stub.dart'
    if (dart.library.js) 'pwa_install_service_web.dart';
