import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hifdh/l10n/generated/app_localizations.dart';
import 'package:hifdh/l10n/somali_material_localizations.dart';
import 'features/settings/logic/theme_provider.dart';
import 'features/settings/logic/locale_provider.dart';
import 'features/settings/logic/preferences_provider.dart';
import 'navigation/main_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/services/app_version_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize app version info
  await AppVersionInfo().init();

  // Initialize providers before runApp
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  final localeProvider = LocaleProvider();
  await localeProvider.init();

  final preferencesProvider = PreferencesProvider();
  await preferencesProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: preferencesProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Hifdh',
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeProvider.applyFont(AppTheme.lightTheme),
      darkTheme: themeProvider.applyFont(AppTheme.darkTheme),
      themeMode: themeProvider.themeMode, // Safe now
      builder: (context, child) {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery == null) {
          return child ?? const SizedBox.shrink();
        }

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(themeProvider.textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
