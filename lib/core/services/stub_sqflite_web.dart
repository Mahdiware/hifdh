// Stub for non-web platforms (Android, iOS, Linux, Windows, macOS)
// This file is imported when dart.library.io is available.

// We don't need the actual factory on IO platforms, but we need the symbol to exist
// so the conditional import works and code compiles.
// However, since we protect usage with kIsWeb, this variable won't be accessed at runtime on IO.

final databaseFactoryFfiWeb = null;
