import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';

/// Modal that shows WalletConnect QR code; user scans with Phantom/Solflare and approves.
/// On approval, session is stored and modal closes.
class WalletConnectModal extends StatefulWidget {
  const WalletConnectModal({super.key});

  @override
  State<WalletConnectModal> createState() => _WalletConnectModalState();
}

class _WalletConnectModalState extends State<WalletConnectModal> {
  Uri? _uri;
  String _status = 'Connecting...';
  bool _connecting = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startConnection();
  }

  Future<void> _startConnection() async {
    final walletState = context.read<WalletState>();
    await walletState.startConnect();
    final wc = walletState.walletConnectService;
    final resp = await wc.connect();
    if (!mounted) return;
    if (resp == null) {
      setState(() {
        _connecting = false;
        _error = 'Failed to create connection';
      });
      return;
    }
    setState(() {
      _uri = resp.uri;
      _status = 'Scan with Phantom or Solflare';
      _connecting = false;
    });
    // Wait for session approval
    SessionData? session;
    try {
      session = await resp.session.future;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _status = 'Connection failed';
        });
      }
      return;
    }
    if (!mounted) return;
    await walletState.onSessionApproved(session);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        final theme = themeNotifier.theme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.gradientColors.first.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white12),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Connect Wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_connecting && _uri == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: Colors.white70),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error.toString(),
                      style: GoogleFonts.poppins(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_uri != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _uri!.toString(),
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
