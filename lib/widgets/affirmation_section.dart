import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/affirmation.dart';
import '../providers/wallet_state.dart';
import '../services/affirmation_service.dart';
import '../services/error_logger.dart';
import '../services/on_chain_affirmation_service.dart';
import '../services/storage_service.dart';
import '../services/widget_update_service.dart';

/// Controller to trigger next affirmation from outside (e.g. full-screen swipe).
class AffirmationSectionController extends ChangeNotifier {
  VoidCallback? _onNext;

  void _attach(VoidCallback onNext) {
    _onNext = onNext;
  }

  void _detach() {
    _onNext = null;
  }

  void next() {
    _onNext?.call();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }
}

/// Large centered affirmation text; swipe UP for next; Favorite and Share.
class AffirmationSection extends StatefulWidget {
  final bool favoritesOnly;
  final AffirmationSectionController? controller;

  const AffirmationSection({
    super.key,
    this.favoritesOnly = false,
    this.controller,
  });

  @override
  State<AffirmationSection> createState() => _AffirmationSectionState();
}

class _AffirmationSectionState extends State<AffirmationSection> {
  Affirmation? _current;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant AffirmationSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(_next);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  Future<void> _refresh() async {
    final service = context.read<AffirmationService>();
    if (service.all.isEmpty) await service.load();
    if (!mounted) return;
    setState(() {
      _current = service.getRandomAffirmation(favoritesOnly: widget.favoritesOnly);
    });
    if (_current != null) {
      StorageService().incrementAffirmationsViewed();
      StorageService().setWidgetAffirmation(_current!.text);
      WidgetUpdateService.notifyWidgetUpdate();
    }
  }

  Future<void> _next() async {
    if (_animating) return;
    final service = context.read<AffirmationService>();
    final storage = StorageService();
    final haptic = await storage.getHapticEnabled();
    if (haptic) HapticFeedback.lightImpact();

    setState(() => _animating = true);
    // Slide up: animate out then in
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _current = service.getRandomAffirmation(favoritesOnly: widget.favoritesOnly);
    });
    if (_current != null) {
      StorageService().incrementAffirmationsViewed();
      StorageService().setWidgetAffirmation(_current!.text);
      WidgetUpdateService.notifyWidgetUpdate();
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _animating = false);
  }

  Future<void> _toggleFavorite() async {
    if (_current == null) return;
    final storage = StorageService();
    final haptic = await storage.getHapticEnabled();
    if (haptic) HapticFeedback.selectionClick();
    await context.read<AffirmationService>().toggleFavorite(_current!);
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    if (_current == null) return;
    try {
      await Share.share(
        _current!.text,
        subject: 'Daily Rabbit Confirmation',
      );
    } catch (e, st) {
      ErrorLogger.log('AffirmationSection.share', e, st);
    }
  }

  Future<void> _onRecordOnChain() async {
    if (_current == null || !mounted) return;
    final wallet = context.read<WalletState>();
    if (!wallet.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connect your wallet first to record on blockchain.',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final dateStr = _formatRecordDate(DateTime.now());
    final costSol = '~0.000005 SOL';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record on Blockchain?', style: GoogleFonts.poppins()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(dateStr, style: GoogleFonts.poppins()),
              const SizedBox(height: 12),
              Text('Affirmation:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(_current!.text, style: GoogleFonts.poppins()),
              const SizedBox(height: 12),
              Text('Cost: $costSol', style: GoogleFonts.poppins(color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Record', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opening wallet… Approve in Solana Seeker.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    final controller = OnChainAffirmationService();
    String? signature;
    try {
      final result = await controller.recordAffirmation(
        walletState: wallet,
        affirmationText: _current!.text,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw TimeoutException('Wallet did not respond. Try again and approve in Solana Seeker.'),
      );
      signature = result.signature;
    } catch (e, st) {
      ErrorLogger.log('AffirmationSection.recordOnChain', e, st);
      if (!mounted) return;
      final message = e is TimeoutException
          ? 'Request timed out. Try again and approve the transaction in Solana Seeker.'
          : 'The wallet did not approve the transaction. When you tap Record, switch to Solana Seeker and approve the request.';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Recording failed', style: GoogleFonts.poppins()),
          content: Text(message, style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RecordSuccessDialog(signature: signature!),
    );
  }

  String _formatRecordDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -50) {
          _next();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _current == null
                  ? const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      ),
                    )
                  : Text(
                      _current!.text,
                      key: ValueKey<String>(_current!.id),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Swipe up for next',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _current?.isFavorite == true ? Icons.favorite : Icons.favorite_border,
                    color: _current?.isFavorite == true ? Colors.red : Colors.white70,
                  ),
                  onPressed: _current == null ? null : _toggleFavorite,
                ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white70),
                  onPressed: _current == null ? null : _share,
                ),
                IconButton(
                  icon: const Icon(Icons.verified, color: Colors.white70),
                  tooltip: 'Record on blockchain',
                  onPressed: _current == null ? null : _onRecordOnChain,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordSuccessDialog extends StatefulWidget {
  final String signature;

  const _RecordSuccessDialog({required this.signature});

  @override
  State<_RecordSuccessDialog> createState() => _RecordSuccessDialogState();
}

class _RecordSuccessDialogState extends State<_RecordSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _truncatedSig {
    final s = widget.signature;
    if (s.length <= 12) return s;
    return '${s.substring(0, 6)}...${s.substring(s.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Recorded on chain', style: GoogleFonts.poppins()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _truncatedSig,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse(
                'https://solscan.io/tx/${widget.signature}',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('View on Solscan', style: GoogleFonts.poppins()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }
}
