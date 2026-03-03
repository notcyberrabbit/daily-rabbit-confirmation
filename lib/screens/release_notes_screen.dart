import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_theme.dart';
import '../providers/theme_notifier.dart';

/// User-facing release notes and feature descriptions. Update when adding new modules.
class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key});

  static const List<({String version, String date, List<String> items})> _entries = [
    (version: '1.0.2 (3)', date: 'Feb 2025', items: [
      'Tasks: Auto reset at midnight (toggle on/off in Task screen)',
      'Tasks: Streak counter and daily log (tap streak to view history)',
      'Tasks: Estimated time per task (minutes) and daily summary',
      'On-Chain Activity: Heatmap calendar, hourly distribution chart',
      'On-Chain Activity: Max/Min TX stats, transaction list with Solscan links',
      'On-Chain Activity: Heatmap color legend (info icon)',
    ]),
    (version: '1.0.1', date: 'Feb 2025', items: [
      'On-Chain Activity: Beta dashboard on Profile',
      'Start screen preference (Main, Task, Mini game, DeFi, Profile)',
    ]),
    (version: '1.0.0', date: '2025', items: [
      'Daily affirmations with favorites',
      'Task list with priorities, links, swipe actions',
      'Tap the Rabbit mini game',
      'DeFi tools (Jupiter swap)',
      'Profile: wallet, balance, statistics',
      'Morning & evening reminders',
      '4 gradient themes',
    ]),
  ];

  String _buildPlainText() {
    final buffer = StringBuffer();
    buffer.writeln("What's New - Daily Rabbit Confirmation");
    buffer.writeln('Features and updates. Updated with each release.');
    buffer.writeln();
    for (final e in _entries) {
      buffer.writeln('v${e.version} (${e.date})');
      for (final item in e.items) {
        buffer.writeln('• $item');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _buildPlainText()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard', style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    await Share.share(_buildPlainText(), subject: "What's New - Daily Rabbit Confirmation");
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        final theme = themeNotifier.theme;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: theme.gradient),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "What's New",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          onPressed: () => _copyToClipboard(context),
                          tooltip: 'Copy',
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.white70),
                          onPressed: () => _share(context),
                          tooltip: 'Share',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      children: [
                        Text(
                          'Features and updates. Updated with each release.',
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ..._entries.map((e) => _buildVersionCard(theme, e)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionCard(AppTheme theme, ({String version, String date, List<String> items}) e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v${e.version}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                e.date,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...e.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: GoogleFonts.poppins(fontSize: 14, color: theme.accentColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
