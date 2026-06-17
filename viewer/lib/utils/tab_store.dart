import 'tab_store_stub.dart' if (dart.library.html) 'tab_store_web.dart' as _impl;

void saveTab(String name) => _impl.saveTab(name);
String? loadTab() => _impl.loadTab();
