/// URL base da API. Em web lê do script no index.html (mesmo host da página, porta 8000).
import 'config_stub.dart' if (dart.library.html) 'config_web.dart' as _impl;

String get kApiBaseUrl => _impl.getApiBaseUrl();
