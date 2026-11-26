import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'data/backend.dart';
import 'routes.dart';
import 'screens/app_lock.dart';
import 'services/app_navigator.dart';
import 'services/local_security.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E1528),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await Backend.init();
  await PushService.instance.init();
  await LocalSecurity.instance.load();
  // Verrouillage après 1 minute en arrière-plan (si un PIN est défini).
  LocalSecurity.instance.onLockRequired = () {
    appNavigator?.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => AppLockScreen(
          onUnlocked: () => Navigator.pop(context),
          onSos: () => Navigator.pushNamed(context, AppRoutes.sos),
        ),
      ),
    );
  };
  runApp(const JammTechApp());
}

class JammTechApp extends StatelessWidget {
  const JammTechApp({super.key, this.initialRoute = AppRoutes.splash});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JammTech',
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: initialRoute,
      routes: appRoutes,
      onGenerateRoute: onGenerateRoute,
    );
  }
}
