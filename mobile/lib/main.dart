import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/fin_theme.dart';
import 'views/auth/passcode_screen.dart';

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

  runApp(const FinVaultApp());
}

class FinVaultApp extends StatelessWidget {
  const FinVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinVault',
      debugShowCheckedModeBanner: false,
      theme: FinTheme.lightTheme,
      darkTheme: FinTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const PasscodeScreen(),
    );
  }
}
