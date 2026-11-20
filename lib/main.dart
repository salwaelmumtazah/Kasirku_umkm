import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'services/ad_service.dart';
import 'services/billing_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.load();

  final billingService = BillingService(settingsService: settingsService);

  // Inisialisasi AdMob & Billing secara non-blocking agar startup tetap cepat saat offline
  AdService.instance.initialize();
  billingService.initialize();

  runApp(
    KasirkuApp(
      settingsService: settingsService,
      billingService: billingService,
    ),
  );
}

class KasirkuApp extends StatelessWidget {
  final SettingsService settingsService;
  final BillingService billingService;

  const KasirkuApp({
    super.key,
    required this.settingsService,
    required this.billingService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kasirku Offline',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(settingsService.themeColor),
          darkTheme: AppTheme.darkTheme(settingsService.themeColor),
          themeMode: settingsService.themeMode,
          home: MainShell(
            settingsService: settingsService,
            billingService: billingService,
          ),
        );
      },
    );
  }
}
