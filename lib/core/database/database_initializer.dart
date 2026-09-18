import 'database_initializer_stub.dart'
    if (dart.library.js_interop) 'database_initializer_web.dart'
    if (dart.library.html) 'database_initializer_web.dart'
    if (dart.library.io) 'database_initializer_io.dart';

Future<void> initDatabasePlatform() => initDatabase();
