import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../services/error_logger.dart';

/// List of errors with timestamps; Copy all / Clear all.
class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        final theme = themeNotifier.theme;
        final entries = ErrorLogger.entries;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: theme.gradient),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'Error logs',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final text = ErrorLogger.exportAll();
                            if (text.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, color: Colors.white70),
                          label: Text(
                            'Copy all',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ErrorLogger.clearAll();
                            _refresh();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                          label: Text(
                            'Clear all',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              'No errors logged',
                              style: GoogleFonts.poppins(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: entries.length,
                            itemBuilder: (context, i) {
                              final e = entries[i];
                              return Card(
                                color: Colors.white12,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.timestamp.toIso8601String(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '[${e.source}] ${e.message}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (e.stackTrace != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          e.stackTrace!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.white38,
                                          ),
                                          maxLines: 5,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
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
