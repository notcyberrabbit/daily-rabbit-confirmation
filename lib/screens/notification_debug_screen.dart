import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../providers/theme_notifier.dart';
import '../services/notification_logger.dart';

/// Debug Logs: notification events for troubleshooting.
class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  final NotificationLogger _logger = NotificationLogger();

  @override
  void initState() {
    super.initState();
    _logger.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _logger.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Logs',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _logger.entries.join('\n')));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied to clipboard', style: GoogleFonts.poppins()),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                        label: Text('Copy', style: GoogleFonts.poppins(color: Colors.white70)),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _logger.clear();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
                        label: Text('Clear', style: GoogleFonts.poppins(color: Colors.white70)),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Notification events (newest first)',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _logger.entries.isEmpty
                        ? Center(
                            child: Text(
                              'No logs yet. Enable notifications and set reminders.',
                              style: GoogleFonts.poppins(color: Colors.white54),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: _logger.entries.length,
                            itemBuilder: (context, i) {
                              final entry = _logger.entries[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    entry,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
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
}
