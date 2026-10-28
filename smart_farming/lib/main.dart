
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );


  runApp(const SmartFarmingApp());
}

class SmartFarmingApp extends StatelessWidget {
  const SmartFarmingApp({
  super.key,
  this.enableFirebase = true,
  });

final bool enableFirebase;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => AppState(enableFirebase: enableFirebase),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Smart Farming Mikiko V4',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: NotificationService.messengerKey,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            home: state.isLoggedIn
                ? const HomeShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
