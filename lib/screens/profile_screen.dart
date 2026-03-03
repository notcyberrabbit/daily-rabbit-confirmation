import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_theme.dart';
import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';
import '../services/affirmation_service.dart';
import '../services/error_logger.dart';
import '../services/mobile_wallet_adapter_service.dart';
import '../services/storage_service.dart';
import '../services/wallet_balance_service.dart';
import '../models/streak_manager.dart';
import 'on_chain_activity_screen.dart';
import '../widgets/wallet_connect_modal.dart';

/// Profile: wallet address, balance (SOL + tokens), statistics, storage info.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  WalletBalances? _balances;
  bool _loadingBalance = false;
  bool _showOnChainAnalytics = true;
  int _affirmationsViewed = 0;
  bool _showAllTokens = false;
  bool _storageCardExpanded = false;
  DateTime? _lastUpdated;
  int _favoritesCount = 0;
  int _tasksCount = 0;
  late AnimationController _refreshController;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = context.read<WalletState>();
      if (wallet.isConnected && _balances == null && !_loadingBalance) {
        _loadBalance(wallet);
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final storage = StorageService();
    await storage.init();
    final n = await storage.getAffirmationsViewed();
    final tasks = await storage.getTasks();
    final favIds = await storage.getFavoriteIds();
    final showOnChain = await storage.getShowOnChainAnalytics();
    if (mounted) {
      setState(() {
        _affirmationsViewed = n;
        _tasksCount = tasks.length;
        _favoritesCount = favIds.length;
        _showOnChainAnalytics = showOnChain;
      });
    }
  }

  Future<void> _loadBalance(WalletState wallet) async {
    final pub = wallet.publicKey;
    if (pub == null) return;
    HapticFeedback.lightImpact();
    setState(() => _loadingBalance = true);
    try {
      final service = WalletBalanceService();
      final b = await service.fetchBalances(pub);
      if (mounted) {
        setState(() {
          _balances = b;
          _loadingBalance = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e, st) {
      ErrorLogger.log('ProfileScreen.fetchBalances', e, st);
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }

  String _formatWithCommas(String raw) {
    final v = double.tryParse(raw) ?? 0;
    if (v >= 1000) {
      final s = v.toStringAsFixed(4);
      final parts = s.split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    }
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeNotifier, WalletState, AffirmationService>(
      builder: (context, themeNotifier, wallet, affService, _) {
        final theme = themeNotifier.theme;
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: theme.gradient),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  _buildAppBar(context),
                  const SizedBox(height: 24),
                  if (!wallet.isConnected) ...[
                    _buildEmptyWalletState(context, theme, wallet),
                  ] else ...[
                    _buildTopSection(context, theme, wallet),
                    const SizedBox(height: 16),
                    _buildBalanceSection(context, theme, wallet),
                    const SizedBox(height: 16),
                    _buildWalletActions(context, theme, wallet),
                    const SizedBox(height: 24),
                  ],
                  _buildStatisticsSection(context, theme, affService),
                  const SizedBox(height: 16),
                  _buildOnChainSection(context, theme, wallet),
                  const SizedBox(height: 16),
                  _buildStorageCard(context, theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: 8),
        Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWalletState(
    BuildContext context,
    AppTheme theme,
    WalletState wallet,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No Wallet Connected',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your Solana wallet to view balance and manage tokens',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _connectWallet(context, wallet),
                icon: const Icon(Icons.link, size: 20),
                label: Text('Connect Now', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(
    BuildContext context,
    AppTheme theme,
    WalletState wallet,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  wallet.truncatedAddress,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ).copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection(
    BuildContext context,
    AppTheme theme,
    WalletState wallet,
  ) {
    if (_loadingBalance) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Text('Loading balance...', style: GoogleFonts.poppins(color: Colors.white70)),
          ],
        ),
      );
    }
    final b = _balances;
    if (b == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton.icon(
          onPressed: () => _loadBalance(wallet),
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          label: Text('Load balance', style: GoogleFonts.poppins(color: Colors.white70)),
        ),
      );
    }

    final tokens = [
      ('◎', 'SOL', b.solFormatted),
      ('💵', 'USDC', b.usdc),
      ('🐶', 'BONK', b.bonk),
      ('🪐', 'JUP', b.jup),
    ];
    final visibleTokens = _showAllTokens
        ? tokens
        : tokens.where((t) {
            final v = double.tryParse(t.$3) ?? 0;
            return v > 0;
          }).toList();
    final hasHidden = tokens.length != visibleTokens.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ...visibleTokens.map((t) => _buildTokenRow(t.$1, t.$2, t.$3)),
          if (hasHidden) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showAllTokens = !_showAllTokens),
              child: Text(
                _showAllTokens ? 'Hide zero balances' : 'Show all tokens',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_lastUpdated != null)
                Text(
                  'Last updated: ${_formatLastUpdated(_lastUpdated!)}',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.white38),
                )
              else
                const SizedBox.shrink(),
              AnimatedBuilder(
                animation: _refreshController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _refreshController.value * 6.28,
                    child: IconButton(
                      onPressed: _loadingBalance
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _refreshController.forward(from: 0);
                              _loadBalance(wallet).then((_) {
                                if (mounted) _refreshController.reset();
                              });
                            },
                      icon: Icon(
                        Icons.refresh,
                        color: _loadingBalance ? Colors.white38 : Colors.white54,
                        size: 18,
                      ),
                      tooltip: 'Refresh',
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow(String emoji, String symbol, String amount) {
    final formatted = symbol == 'SOL'
        ? '$amount SOL'
        : '${_formatWithCommas(amount)} $symbol';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              symbol,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
            ),
          ),
          Text(
            formatted,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletActions(
    BuildContext context,
    AppTheme theme,
    WalletState wallet,
  ) {
    final address = wallet.publicKey ?? '';
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.copy,
            label: 'Copy Address',
            onPressed: () {
              if (address.isEmpty) return;
              Clipboard.setData(ClipboardData(text: address));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Address copied!', style: GoogleFonts.poppins()),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.open_in_new,
            label: 'View Explorer',
            onPressed: () async {
              if (address.isEmpty) return;
              final uri = Uri.parse('https://solscan.io/account/$address');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: Icons.link_off,
            label: 'Disconnect',
            onPressed: () => _showDisconnectConfirm(context, wallet),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDisconnectConfirm(BuildContext context, WalletState wallet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Disconnect wallet?', style: GoogleFonts.poppins()),
        content: Text(
          'This will disconnect your wallet from the app and clear stored wallet data.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Disconnect', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await wallet.disconnect();
      setState(() {
        _balances = null;
        _lastUpdated = null;
      });
    }
  }

  Widget _buildStatisticsSection(
    BuildContext context,
    AppTheme theme,
    AffirmationService affService,
  ) {
    return Consumer<StreakManager>(
      builder: (context, streakManager, _) {
        final carrotsFuture = StorageService().getMiniplayTotalCarrots();
        return FutureBuilder<int>(
          future: carrotsFuture,
          builder: (context, snap) {
            final totalCarrots = snap.data ?? 0;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistics',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  _buildStatRow('🔥 Current streak', '${streakManager.currentStreak} days'),
                  _buildStatRow('📖 Affirmations viewed', '$_affirmationsViewed'),
                  _buildStatRow('❤️ Favorites', '${affService.favorites.length}'),
                  _buildStatRow('🎮 Total carrots', '$totalCarrots'),
                  _buildStatRow('🗓️ Member since', '—'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnChainSection(
    BuildContext context,
    AppTheme theme,
    WalletState wallet,
  ) {
    if (!_showOnChainAnalytics || !wallet.isConnected) return const SizedBox.shrink();
    final address = wallet.publicKey;
    if (address == null || address.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnChainActivityScreen(),
        ),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2749).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'On-Chain Activity',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.accentColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          'BETA',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Calendar, stats, date range, tx details',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white54, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, AppTheme theme) {
    return InkWell(
      onTap: () => setState(() => _storageCardExpanded = !_storageCardExpanded),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Storage',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
                ),
                Icon(
                  _storageCardExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
            if (_storageCardExpanded) ...[
              const SizedBox(height: 12),
              _buildStatRow('Favorites saved', '$_favoritesCount'),
              _buildStatRow('Tasks created', '$_tasksCount'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _connectWallet(BuildContext context, WalletState wallet) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final available = await MobileWalletAdapterService.isWalletAvailable();
      if (!context.mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Install Solana Seeker (or another MWA wallet) from the store.',
              style: GoogleFonts.poppins(),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening wallet...', style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    await wallet.startConnect();
    if (!context.mounted) return;
    if (wallet.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected: ${wallet.truncatedAddress}', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadBalance(wallet);
      _loadStats();
    } else {
      if (defaultTargetPlatform != TargetPlatform.android) {
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => const WalletConnectModal(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection cancelled.', style: GoogleFonts.poppins()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
