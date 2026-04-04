/// URL base da API. Em web: query `api_base`, depois mesmo host na porta 8001 (Docker).
library;

import 'config_stub.dart' if (dart.library.html) 'config_web.dart' as impl;

String get kApiBaseUrl => impl.getApiBaseUrl();
