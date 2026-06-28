// Dispatcher condicional: na VM (flutter test) exporta stubs sem imports web;
// no browser exporta a implementação real com package:web e dart:js_interop.
export 'face_detection_service_stub.dart'
    if (dart.library.html) 'face_detection_service_impl.dart';
