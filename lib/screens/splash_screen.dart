import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/streak_manager.dart';
import '../providers/theme_notifier.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/widget_update_service.dart';
import 'defi_tools_screen.dart';
import 'main_screen.dart';
import 'miniplay_screen.dart';
import 'profile_screen.dart';
import 'task_screen.dart';

/// Splash: pulsating rabbit logo, greeting, streak. Navigates to Main after 2s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStreakAndNavigate());
  }

  Future<void> _loadStreakAndNavigate() async {
    final context = this.context;
    final storage = StorageService();
    await storage.init();
    try {
      final streakManager = context.read<StreakManager>();
      final current = await storage.getCurrentStreak();
      final last = await storage.getLastCheckIn();
      final longest = await storage.getLongestStreak();
      streakManager.load(current, last, longest);
      streakManager.checkIn();
      await storage.setCurrentStreak(streakManager.currentStreak);
      await storage.setLastCheckIn(streakManager.lastCheckIn);
      await storage.setLongestStreak(streakManager.longestStreak);
      await NotificationService().applySettings();
      if (Platform.isAndroid) WidgetUpdateService.notifyWidgetUpdate();
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
    if (!mounted) return;
    final startScreen = await storage.getStartScreen();
    if (startScreen != 'main') {
      Widget? target;
      switch (startScreen) {
        case 'task':
          target = const TaskScreen();
          break;
        case 'minigame':
          target = const MiniplayScreen();
          break;
        case 'defi':
          target = const DefiToolsScreen();
          break;
        case 'profile':
          target = const ProfileScreen();
          break;
      }
      if (target != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => target!),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: StorageService().getName(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? 'Friend';
        return Consumer2<ThemeNotifier, StreakManager>(
          builder: (context, themeNotifier, streakManager, _) {
            final theme = themeNotifier.theme;
            return Scaffold(
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: theme.gradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Text(
                          '🐰',
                          style: TextStyle(
                            fontSize: 72,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'GM, $name, welcome back today!',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '🔥 ${streakManager.currentStreak} days',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          color: theme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
