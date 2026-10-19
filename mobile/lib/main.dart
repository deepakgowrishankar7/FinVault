import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/user_role.dart';
import 'services/storage_service.dart';
import 'theme/app_locale.dart';
import 'theme/fin_theme.dart';
import 'views/auth/passcode_screen.dart';
import 'views/auth/setup_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style (Apple transparent status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final settings = await StorageService.getSettings();
  AppLocale.currentLang = settings.language;

  runApp(FinVaultApp(initialSettings: settings));
}

class FinVaultApp extends StatelessWidget {
  final SecuritySettings initialSettings;

  const FinVaultApp({super.key, required this.initialSettings});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentLangNotifier,
      builder: (context, lang, child) {
        return MaterialApp(
          key: ValueKey(lang),
          title: 'FinVault',
          debugShowCheckedModeBanner: false,
          theme: FinTheme.lightTheme,
          darkTheme: FinTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: initialSettings.isRegistered ? const PasscodeScreen() : const SetupWizardScreen(),
        );
      },
    );
  }
}
