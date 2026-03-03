import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';
import '../services/donation_service.dart';

/// Bottom sheet panel for SOL donations. Quick amounts, custom amount, and CTA.
void showDonatePanel(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const DonatePanel(),
  );
}

class DonatePanel extends StatefulWidget {
  const DonatePanel({super.key});

  @override
  State<DonatePanel> createState() => _DonatePanelState();
}

class _DonatePanelState extends State<DonatePanel> {
  static const List<double> _quickAmounts = [0.01, 0.02, 0.05];
  int _selectedQuickIndex = 1; // 0.02 default
  bool _useCustom = false;
  final _customController = TextEditingController(text: '');
  final _customFocus = FocusNode();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  double get _amount {
    if (_useCustom) {
      final v = double.tryParse(_customController.text.replaceAll(',', '.'));
      return v ?? 0;
    }
    return _quickAmounts[_selectedQuickIndex];
  }

  /// Format SOL amount with up to 6 decimals, trim trailing zeros.
  static String _formatSol(double amount) {
    final s = amount.toStringAsFixed(6);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _donate() async {
    final amount = _amount;
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final wallet = context.read<WalletState>();
    if (!wallet.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connect your wallet first.',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    // In-app confirmation: amount visible before wallet opens (wallet may show "no change")
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirm donation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send ${_formatSol(amount)} SOL to Daily Rabbit Confirmation.',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Your wallet will ask you to sign the transaction. If it shows „no change” , that is a display issue. The selected amount will be sent correctly.',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Send (${_formatSol(amount)} SOL)', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      final sig = await DonationService().sendDonation(
        walletState: wallet,
        solAmount: amount,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you! ${_formatSol(amount)} SOL sent.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, _) {
        final theme = themeNotifier.theme;
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: theme.gradientColors.first.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Support Daily Rabbit Confirmation',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a donation to keep Daily Rabbit Confirmation shipping.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Quick amounts',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 0; i < _quickAmounts.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _AmountChip(
                          label: '${_formatSol(_quickAmounts[i])} SOL',
                          selected: !_useCustom && _selectedQuickIndex == i,
                          onTap: () {
                            setState(() {
                              _useCustom = false;
                              _selectedQuickIndex = i;
                              _error = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Custom amount (SOL)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _customController,
                  focusNode: _customFocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _useCustom = true;
                      _error = null;
                    });
                  },
                  onTap: () => setState(() => _useCustom = true),
                ),
                const SizedBox(height: 16),
                Text(
                  'Donations fund infrastructure, data, and research. Thank you!',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify the amount before signing.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending ? null : _donate,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.volunteer_activism, size: 22),
                  label: Text(
                    _sending ? 'Sending...' : 'Donate ${_formatSol(_amount)} SOL',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'What your donation supports?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your support keeps Daily Rabbit Confirmation free and improving: '
                  'servers, data pipelines, and research for better affirmations and DeFi tools. '
                  'We’re grateful for every contribution—thank you for being part of the journey.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white24 : Colors.white12,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
