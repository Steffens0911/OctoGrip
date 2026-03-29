import 'api_base_persist_stub.dart'
    if (dart.library.html) 'api_base_persist_web.dart' as impl;

void persistApiBaseAndReload(String base) => impl.persistApiBaseAndReload(base);
