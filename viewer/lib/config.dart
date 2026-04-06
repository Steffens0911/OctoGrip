/// URL base da API. Em web: `API_BASE_URL` no build, query `api_base`, depois fallbacks locais.
library;

import 'config_stub.dart' if (dart.library.html) 'config_web.dart' as impl;

String get kApiBaseUrl => impl.getApiBaseUrl();
