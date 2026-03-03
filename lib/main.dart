import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/settings_notifier.dart';
import 'providers/theme_notifier.dart';
import 'providers/wallet_state.dart';
import 'screens/splash_screen.dart';
import 'services/affirmation_service.dart';
import 'services/notification_service.dart';
import 'models/streak_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initialize();
  runApp(const DailyRabbitApp());
}

/// Root app: providers, theme, and splash as initial route.
class DailyRabbitApp extends StatelessWidget {
  const DailyRabbitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..load()),
        ChangeNotifierProvider(create: (_) => StreakManager()),
        ChangeNotifierProvider(create: (_) => WalletState()),
        Provider(create: (_) => AffirmationService()..load()),
        ChangeNotifierProvider(create: (_) => SettingsNotifier()..load()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'Daily Rabbit Confirmation',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.dark(
                primary: themeNotifier.theme.accentColor,
                surface: themeNotifier.theme.gradientColors.first,
                onPrimary: Colors.white,
                onSurface: Colors.white,
              ),
              textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            ),
            home: const _WalletConnectInit(child: SplashScreen()),
          );
        },
      ),
    );
  }
}

/// Ensures WalletConnect is initialized and session restored on app start.
class _WalletConnectInit extends StatefulWidget {
  const _WalletConnectInit({required this.child});

  final Widget child;

  @override
  State<_WalletConnectInit> createState() => _WalletConnectInitState();
}

class _WalletConnectInitState extends State<_WalletConnectInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletState>().ensureInitialized();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
