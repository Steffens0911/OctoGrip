/// URL base da API. Em web lê do script no index.html (mesmo host da página, porta 8000).
library;

import 'config_stub.dart' if (dart.library.html) 'config_web.dart' as impl;

String get kApiBaseUrl => impl.getApiBaseUrl();
