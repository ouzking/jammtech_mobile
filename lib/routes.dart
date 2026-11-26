import 'package:flutter/material.dart';

import 'screens/screens.dart';
import 'services/inbox_service.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const verifyPhone = '/verify_phone';
  static const forgotPassword = '/forgot_password';
  static const home = '/home';
  static const map = '/map';
  static const alerts = '/alerts';
  static const sos = '/sos';
  static const smartHome = '/smart_home';
  static const profile = '/profile';
  static const videoHistory = '/video_history';
  static const settings = '/settings';
  static const security = '/security';
  static const securityCodes = '/security_codes';
  static const notifications = '/notifications';
  static const help = '/help';
  static const contacts = '/contacts';
  static const protectedPeople = '/protected_people';
  static const liveTracking = '/live_tracking';
  static const transport = '/transport';
  static const startTrip = '/start_trip';
  static const tripCheckin = '/trip_checkin';
  static const watchTrip = '/watch_trip';
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (_) => const SplashScreen(),
  AppRoutes.onboarding: (_) => const OnboardingScreen(),
  AppRoutes.login: (_) => const LoginScreen(),
  AppRoutes.register: (_) => const RegisterScreen(),
  AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
  // L'accueil est une coquille à onglets ; les autres routes ouvrent
  // directement l'onglet ou l'écran concerné.
  AppRoutes.home: (_) => const MainShell(),
  AppRoutes.map: (_) => const MapScreen(standalone: true),
  AppRoutes.alerts: (_) => const AlertsScreen(standalone: true),
  AppRoutes.smartHome: (_) => const SmartHomeScreen(standalone: true),
  AppRoutes.profile: (_) => const ProfileScreen(standalone: true),
  AppRoutes.sos: (_) => const SosScreen(),
  AppRoutes.videoHistory: (_) => const VideoHistoryScreen(),
  AppRoutes.settings: (_) => const SettingsScreen(),
  AppRoutes.security: (_) => const SecurityScreen(),
  AppRoutes.securityCodes: (_) => const SecurityCodesScreen(),
  AppRoutes.notifications: (_) => const NotificationsScreen(),
  AppRoutes.help: (_) => const HelpScreen(),
  AppRoutes.contacts: (_) => const ContactsScreen(),
  AppRoutes.protectedPeople: (_) => const ProtectedPeopleScreen(),
  AppRoutes.transport: (_) => const TransportScreen(standalone: true),
  AppRoutes.startTrip: (_) => const StartTripScreen(),
};

/// Routes qui reçoivent des arguments.
Route<dynamic>? onGenerateRoute(RouteSettings s) {
  switch (s.name) {
    case AppRoutes.verifyPhone:
      return MaterialPageRoute(
        settings: s,
        builder: (_) => VerifyPhoneScreen(phone: s.arguments as String),
      );
    case AppRoutes.tripCheckin:
      return MaterialPageRoute(
        settings: s,
        fullscreenDialog: true,
        builder: (_) => TripCheckinScreen(round: (s.arguments as int?) ?? 1),
      );
    case AppRoutes.watchTrip:
      return MaterialPageRoute(
        settings: s,
        builder: (_) => WatchTripScreen(tripId: s.arguments as String),
      );
    case AppRoutes.liveTracking:
      return MaterialPageRoute(
        settings: s,
        fullscreenDialog: true,
        builder: (_) =>
            LiveTrackingScreen(args: s.arguments as LiveTrackingArgs),
      );
  }
  return null;
}
