import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_theme.dart';
import '../models/on_chain_activity.dart';
import '../providers/theme_notifier.dart';
import '../providers/wallet_state.dart';
import '../services/blockchain_analytics_service.dart';

/// Full-screen On-Chain Activity: Beta badge, calendar, date range, daily stats, tx list.
class OnChainActivityScreen extends StatefulWidget {
  const OnChainActivityScreen({super.key});

  @override
  State<OnChainActivityScreen> createState() => _OnChainActivityScreenState();
}

class _OnChainActivityScreenState extends State<OnChainActivityScreen> {
  final BlockchainAnalyticsService _service = BlockchainAnalyticsService();
  int _periodDays = 7;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _focusedDay = DateTime.now();
  OnChainActivityData? _data;
  bool _loading = false;
  String? _error;
  bool _showCalendar = true;
  bool _showDetails = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String? get _walletAddress => context.read<WalletState>().publicKey;

  Future<void> _fetch() async {
    final addr = _walletAddress;
    if (addr == null || addr.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchActivity(
        addr,
        _periodDays,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('timeout')
              ? 'Request timed out – RPC may be slow. Try again or use a shorter period.'
              : 'Unable to fetch data. Try again.';
          _loading = false;
        });
      }
    }
  }

  void _applyDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
      _fetch();
    });
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
                  _buildAppBar(theme),
                  Expanded(
                    child: _walletAddress == null || _walletAddress!.isEmpty
                        ? _buildNoWallet(theme)
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            children: [
                              _buildBetaBadge(theme),
                              const SizedBox(height: 16),
                              _buildPeriodChips(theme),
                              const SizedBox(height: 16),
                              _buildDateRangeSection(theme),
                              const SizedBox(height: 16),
                              if (_loading)
                                _buildLoading()
                              else if (_error != null)
                                _buildError()
                              else if (_data != null && _data!.summary.total == 0)
                                _buildEmpty()
                              else if (_data != null) ...[
                                if (_data!.dataTruncated) _buildTruncationBanner(theme),
                                if (_data!.dataTruncated) const SizedBox(height: 8),
                                _buildStatRow(theme),
                                const SizedBox(height: 16),
                                if (_showCalendar) _buildCalendar(theme),
                                const SizedBox(height: 16),
                                _buildHourlyChart(theme),
                                const SizedBox(height: 16),
                                if (_data!.transactions.isNotEmpty) ...[
                                  _buildDetailsHeader(theme),
                                  if (_showDetails) ...[
                                    const SizedBox(height: 8),
                                    _buildTransactionList(_data!.transactions, theme),
                                  ],
                                ],
                              ],
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

  Widget _buildAppBar(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Text(
            'On-Chain Activity',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetaBadge(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'BETA',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Experimental feature',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWallet(AppTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Connect a wallet to view on-chain activity.',
          style: GoogleFonts.poppins(fontSize: 15, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPeriodChips(AppTheme theme) {
    return Row(
      children: [7, 30, 90].map((d) {
        final selected = _periodDays == d && _startDate == null && _endDate == null;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text('$d Days', style: GoogleFonts.poppins(fontSize: 12)),
            selected: selected,
            onSelected: (_) {
              HapticFeedback.lightImpact();
              setState(() {
                _periodDays = d;
                _startDate = null;
                _endDate = null;
                _fetch();
              });
            },
            selectedColor: theme.accentColor.withValues(alpha: 0.5),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeSection(AppTheme theme) {
    return Container(
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
                'Date range',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
              TextButton(
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : DateTimeRange(
                            start: DateTime.now().subtract(Duration(days: _periodDays)),
                            end: DateTime.now(),
                          ),
                  );
                  if (range != null) _applyDateRange(range.start, range.end);
                },
                child: Text(
                  'Select range',
                  style: GoogleFonts.poppins(fontSize: 12, color: theme.accentColor),
                ),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_formatDate(_startDate!)} – ${_formatDate(_endDate!)}',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showHeatmapLegend(BuildContext context) {
    final items = [
      (Colors.white.withValues(alpha: 0.06), '0 TX: Grey/dark (empty)'),
      (const Color(0xFF90CAF9), '1–10 TX: Light blue'),
      (const Color(0xFF42A5F5), '11–20 TX: Medium blue'),
      (const Color(0xFF2196F3), '20–50 TX: Bright blue'),
      (const Color(0xFF9C27B0), '51+ TX: Purple'),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: Text('Heatmap colors', style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: e.$1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.$2, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70)),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Color _heatmapColorForCount(int count, AppTheme theme) {
    if (count == 0) return Colors.white.withValues(alpha: 0.06);
    if (count <= 10) return const Color(0xFF90CAF9);
    if (count <= 20) return const Color(0xFF42A5F5);
    if (count <= 50) return const Color(0xFF2196F3);
    return const Color(0xFF9C27B0);
  }

  Widget _buildTruncationBanner(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.orange.shade200),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'RPC limit reached – data may be incomplete. Try a shorter period.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(AppTheme theme) {
    final countByDate = <DateTime, int>{};
    for (final d in _data?.dailyActivity ?? []) {
      countByDate[d.date] = d.count;
    }
    return Container(
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
              Row(
                children: [
                  Text(
                    'Calendar',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18, color: Colors.white54),
                    onPressed: () => _showHeatmapLegend(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Heatmap legend',
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _showCalendar ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _showCalendar = !_showCalendar),
              ),
            ],
          ),
          if (_showCalendar)
            TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now(),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.white70),
                      weekendTextStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                      selectedTextStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.white),
                      todayTextStyle: GoogleFonts.poppins(fontSize: 11, color: theme.accentColor),
                      cellMargin: const EdgeInsets.all(2),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleTextStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, date, _) {
                        final day = DateTime(date.year, date.month, date.day);
                        final count = countByDate[day] ?? 0;
                        final color = _heatmapColorForCount(count, theme);
                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: count == 0 ? Colors.white38 : Colors.white,
                                fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                      selectedBuilder: (context, date, _) {
                        final day = DateTime(date.year, date.month, date.day);
                        final count = countByDate[day] ?? 0;
                        final color = _heatmapColorForCount(count, theme);
                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.accentColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                      todayBuilder: (context, date, _) {
                        final day = DateTime(date.year, date.month, date.day);
                        final count = countByDate[day] ?? 0;
                        final color = _heatmapColorForCount(count, theme);
                        return Container(
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.accentColor.withValues(alpha: 0.8), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: theme.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    onDaySelected: (selected, focused) {
                      setState(() => _focusedDay = focused);
                      _applyDateRange(selected, selected);
                    },
                  ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching blockchain data...',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            _error!,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.orange),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
            label: Text('Retry', style: GoogleFonts.poppins(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            'No On-Chain Activity',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start using your wallet to see activity here.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(AppTheme theme) {
    final s = _data!.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: theme.accentColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total TXs',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      '${s.total}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_up, size: 20, color: theme.accentColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Max/day',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      '${s.maxTxPerDay}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.trending_down, size: 20, color: theme.accentColor),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Min/day',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                    ),
                    Text(
                      '${s.minTxPerDay}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(AppTheme theme) {
    final hourly = _data!.hourlyDistribution;
    final hasData = hourly.isNotEmpty && hourly.any((c) => c > 0);
    final maxVal = hasData ? hourly.map((c) => c.toDouble()).reduce((a, b) => a > b ? a : b) : 0.0;
    final maxH = maxVal > 0 ? maxVal * 1.1 : 1.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly distribution',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          hasData
              ? SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxH,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, meta) {
                        final h = v.toInt();
                        if (h >= 0 && h < 24 && h % 4 == 0) {
                          return Text(
                            '$h',
                            style: GoogleFonts.poppins(fontSize: 9, color: Colors.white54),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: hourly.asMap().entries.map((e) {
                  final h = e.value.toDouble();
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: h,
                        color: theme.accentColor,
                        width: 6,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ],
                    showingTooltipIndicators: [0],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 200),
            ),
          )
              : Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No hourly data',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsHeader(AppTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Transaction details',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
        IconButton(
          icon: Icon(
            _showDetails ? Icons.expand_less : Icons.expand_more,
            color: Colors.white54,
          ),
          onPressed: () => setState(() => _showDetails = !_showDetails),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<TransactionItem> txs, AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...txs.map((tx) => _buildTxTile(tx, theme)),
        ],
      ),
    );
  }

  IconData _iconForType(TxDisplayType type) {
    return switch (type) {
      TxDisplayType.swap => Icons.swap_horiz,
      TxDisplayType.send => Icons.arrow_upward,
      TxDisplayType.receive => Icons.arrow_downward,
      TxDisplayType.nftMint => Icons.image,
      TxDisplayType.contract => Icons.settings,
      TxDisplayType.unknown => Icons.receipt_long,
    };
  }

  Color _colorForTx(TransactionItem tx, AppTheme theme) {
    if (tx.hasError == true) return Colors.orange;
    if (tx.type == TxDisplayType.receive || tx.isIncoming == true) return const Color(0xFF4CAF50);
    if (tx.type == TxDisplayType.send || tx.isIncoming == false) return Colors.white70;
    return theme.accentColor;
  }

  Widget _buildTxTile(TransactionItem tx, AppTheme theme) {
    final timeStr = tx.blockTime != null
        ? '${_formatDate(tx.blockTime!)} ${tx.blockTime!.hour.toString().padLeft(2, '0')}:${tx.blockTime!.minute.toString().padLeft(2, '0')}'
        : '—';
    final label = tx.actionLabel ?? 'Transaction';
    final sigShort = tx.signature.length > 12
        ? '${tx.signature.substring(0, 6)}...${tx.signature.substring(tx.signature.length - 6)}'
        : tx.signature;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://solscan.io/tx/${tx.signature}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              tx.hasError == true ? Icons.error_outline : _iconForType(tx.type),
              size: 24,
              color: _colorForTx(tx, theme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    tx.protocol != null ? '${tx.protocol!} · $timeStr' : timeStr,
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
                  ),
                  Text(
                    sigShort,
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.white38).copyWith(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 18, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
