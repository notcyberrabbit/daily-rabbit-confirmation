import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/app_theme.dart';
import '../models/streak_manager.dart';
import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';
import '../providers/settings_notifier.dart';
import '../services/affirmation_service.dart';
import '../services/mobile_wallet_adapter_service.dart';
import '../services/storage_service.dart';
import '../widgets/affirmation_section.dart';
import '../services/error_logger.dart';
import '../widgets/wallet_connect_modal.dart';
import '../widgets/donate_panel.dart';
import 'defi_tools_screen.dart';
import 'miniplay_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'task_screen.dart';

void _logConnect(String message, [Object? detail]) {
  final line = '$message${detail != null ? ': $detail' : ''}';
  if (kDebugMode) {
    debugPrint('[Connect] $line');
  }
  ErrorLogger.info('Connect', line);
}

/// Main scrollable page: header, affirmation section, rabbit. Swipe anywhere for next affirmation.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: themeNotifier.theme.gradient,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context, themeNotifier.theme.accentColor),
                  Expanded(
                    child: _MainScrollContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const Color _headerIconColor = Colors.white;
  static const double _headerIconSize = 22;

  Widget _buildHeader(BuildContext context, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: left: Settings + Profile, right: Connect (icons only)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.settings, color: _headerIconColor, size: _headerIconSize),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                tooltip: 'Settings',
              ),
              IconButton(
                icon: const Icon(Icons.person, color: _headerIconColor, size: _headerIconSize),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                tooltip: 'Profile',
              ),
              const Spacer(),
              Consumer<WalletState>(
                builder: (context, wallet, _) {
                  return IconButton(
                    onPressed: () => _onConnectPressed(context, wallet),
                    icon: Icon(
                      wallet.isConnected ? Icons.link_off : Icons.link,
                      color: _headerIconColor,
                      size: _headerIconSize,
                    ),
                    tooltip: wallet.isConnected ? wallet.truncatedAddress : 'Connect',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Task, Mini game, DeFi, Donate (icons only)
          Row(
            children: [
              _navIcon(context, Icons.task_alt, 'Task', () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TaskScreen()),
              )),
              const SizedBox(width: 4),
              _navIcon(context, Icons.games, 'Mini game', () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MiniplayScreen()),
              )),
              const SizedBox(width: 4),
              _navIcon(context, Icons.account_balance_wallet, 'DeFi', () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DefiToolsScreen()),
              )),
              const SizedBox(width: 4),
              _navIcon(context, Icons.volunteer_activism, 'Donate', () => showDonatePanel(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navIcon(BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: _headerIconColor, size: _headerIconSize),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(8),
        minimumSize: const Size(40, 40),
      ),
    );
  }

  Future<void> _onConnectPressed(BuildContext context, WalletState wallet) async {
    _logConnect('Connect button pressed', 'isConnected=${wallet.isConnected}');
    if (wallet.isConnected) {
      _logConnect('Disconnecting');
      await wallet.disconnect();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _logConnect('Disconnected done');
    } else {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _logConnect('Android path: checking isWalletAvailable');
        final available = await MobileWalletAdapterService.isWalletAvailable();
        _logConnect('isWalletAvailable', available);
        if (!context.mounted) return;
        if (!available) {
          _logConnect('No wallet available, showing install message');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Install Solana Seeker (or another MWA wallet) from the store, then try again.',
                style: GoogleFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening wallet...', style: GoogleFonts.poppins()),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        _logConnect('Calling wallet.startConnect()');
        await wallet.startConnect();
        _logConnect('startConnect() returned', 'isConnected=${wallet.isConnected}');
        if (!context.mounted) return;
        if (wallet.isConnected) {
          _logConnect('Showing Connected snackbar', wallet.truncatedAddress);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected: ${wallet.truncatedAddress}', style: GoogleFonts.poppins()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          _logConnect('Not connected: showing cancelled message');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connection cancelled. Try again and approve in Solana Seeker.',
                style: GoogleFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const WalletConnectModal(),
        );
      }
    }
  }

}

/// Scrollable content with full-screen swipe for next affirmation.
class _MainScrollContent extends StatefulWidget {
  @override
  State<_MainScrollContent> createState() => _MainScrollContentState();
}

class _MainScrollContentState extends State<_MainScrollContent> {
  final AffirmationSectionController _affirmationController =
      AffirmationSectionController();
  double? _pointerStartY;
  double? _pointerStartTime;

  @override
  void dispose() {
    _affirmationController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointerStartY = e.position.dy;
    _pointerStartTime = DateTime.now().millisecondsSinceEpoch.toDouble();
  }

  void _onPointerUp(PointerUpEvent e) {
    final startY = _pointerStartY;
    final startTime = _pointerStartTime;
    _pointerStartY = null;
    _pointerStartTime = null;
    if (startY == null || startTime == null) return;
    final deltaY = startY - e.position.dy;
    final deltaTime = DateTime.now().millisecondsSinceEpoch - startTime;
    if (deltaTime <= 0) return;
    final velocity = deltaY / deltaTime;
    if (deltaY > 30 && velocity > 0.15) {
      _affirmationController.next();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) {
        _pointerStartY = null;
        _pointerStartTime = null;
      },
      child: FutureBuilder<bool>(
        future: _loadStreakAndCheckIn(context),
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              top: 40,
              left: 20,
              right: 20,
              bottom: 32,
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Consumer2<AffirmationService, SettingsNotifier>(
                  builder: (context, aff, settings, _) {
                    return AffirmationSection(
                      favoritesOnly: settings.favoritesOnly,
                      controller: _affirmationController,
                    );
                  },
                ),
                const SizedBox(height: 48),
                Consumer<ThemeNotifier>(
                  builder: (context, themeNotifier, _) {
                    return _RabbitWithAmoeba(theme: themeNotifier.theme);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<bool> _loadStreakAndCheckIn(BuildContext context) async {
    try {
      final storage = StorageService();
      await storage.init();
      final streakManager = context.read<StreakManager>();
      final current = await storage.getCurrentStreak();
      final last = await storage.getLastCheckIn();
      final longest = await storage.getLongestStreak();
      streakManager.load(current, last, longest);
      streakManager.checkIn();
      await storage.setCurrentStreak(streakManager.currentStreak);
      await storage.setLastCheckIn(streakManager.lastCheckIn);
      await storage.setLongestStreak(streakManager.longestStreak);
    } catch (_) {}
    return true;
  }
}

/// Rabbit (same as miniplay) with an amoeba-like morphing ring in SOL token colors.
class _RabbitWithAmoeba extends StatefulWidget {
  final AppTheme theme;

  const _RabbitWithAmoeba({required this.theme});

  @override
  State<_RabbitWithAmoeba> createState() => _RabbitWithAmoebaState();
}

class _RabbitWithAmoebaState extends State<_RabbitWithAmoeba>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _AmoebaBlobPainter(
                      progress: _controller.value,
                      solGreen: const Color(0xFF00FFA3),
                      solPurple: const Color(0xFF9945FF),
                      solCyan: const Color(0xFF03E1FF),
                    ),
                  ),
                  const Text(
                    '🐰',
                    style: TextStyle(fontSize: 88, height: 1),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws an organic amoeba-like blob that morphs over time. SOL colors.
class _AmoebaBlobPainter extends CustomPainter {
  final double progress;
  final Color solGreen;
  final Color solPurple;
  final Color solCyan;

  _AmoebaBlobPainter({
    required this.progress,
    required this.solGreen,
    required this.solPurple,
    required this.solCyan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 75.0;
    const numPoints = 80; // more points = smoother curve, less pixelated
    final path = Path();
    const twoPi = 2 * math.pi;
    for (var i = 0; i <= numPoints; i++) {
      final t = (i / numPoints) * twoPi;
      final wave = 0.25 + 0.15 * math.sin(progress * twoPi + t * 2) + 0.1 * math.sin(progress * 4 * math.pi + i * 0.7);
      final r = radius * (1 + wave);
      final x = center.dx + r * math.cos(t);
      final y = center.dy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    final gradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: twoPi,
      colors: [solGreen, solCyan, solPurple, solGreen],
    );
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final strokePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawPath(path, strokePaint);
    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill
      ..color = solGreen.withOpacity(0.12)
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _AmoebaBlobPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

