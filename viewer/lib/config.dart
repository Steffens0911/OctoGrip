/// URL base da API. Em web: query `api_base`, sessionStorage, `API_BASE_URL` no build, fallbacks.
library;

import 'config_stub.dart' if (dart.library.html) 'config_web.dart' as impl;

String get kApiBaseUrl => impl.getApiBaseUrl();
