import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_theme.dart';
import '../models/on_chain_activity.dart';
import '../services/blockchain_analytics_service.dart';

/// On-Chain Activity Dashboard widget for Profile screen.
class OnChainActivityDashboard extends StatefulWidget {
  final String walletAddress;
  final AppTheme theme;

  const OnChainActivityDashboard({
    super.key,
    required this.walletAddress,
    required this.theme,
  });

  @override
  State<OnChainActivityDashboard> createState() => _OnChainActivityDashboardState();
}

class _OnChainActivityDashboardState extends State<OnChainActivityDashboard> {
  final BlockchainAnalyticsService _service = BlockchainAnalyticsService();
  int _periodDays = 7;
  OnChainActivityData? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchActivity(widget.walletAddress, _periodDays);
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
              ? 'Request timed out'
              : 'Unable to fetch data. Try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2749).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'On-Chain Activity',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [7, 30, 90].map((d) {
              final selected = _periodDays == d;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('$d Days', style: GoogleFonts.poppins(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) {
                    HapticFeedback.lightImpact();
                    setState(() => _periodDays = d);
                    _fetch();
                  },
                  selectedColor: widget.theme.accentColor.withValues(alpha: 0.5),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (_loading)
            _buildLoading()
          else if (_error != null)
            _buildError()
          else if (_data != null && _data!.summary.total == 0)
            _buildEmpty()
          else if (_data != null)
            _buildContent()
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://solscan.io/account/${widget.walletAddress}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text('View on Solscan', style: GoogleFonts.poppins()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatGrid(d.summary),
        const SizedBox(height: 16),
        if (d.breakdown.isNotEmpty) ...[
          Text(
            'Transaction Types',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _buildBreakdown(d.breakdown),
          const SizedBox(height: 16),
        ],
        if (d.dailyActivity.isNotEmpty) ...[
          Text(
            'Activity by Day',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _buildHeatmap(d.dailyActivity),
          const SizedBox(height: 16),
          _buildVolumeChart(d.dailyActivity),
          const SizedBox(height: 16),
        ],
        if (d.topInteractions.isNotEmpty) ...[
          Text(
            'Most Interacted Addresses',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _buildTopInteractions(d.topInteractions),
        ],
      ],
    );
  }

  Widget _buildStatGrid(TransactionSummary s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard('Total', '${s.total} TXs', Icons.receipt_long),
        _buildStatCard('Volume', '${s.volumeSol.toStringAsFixed(2)} SOL', Icons.account_balance_wallet),
        _buildStatCard('Sent', '${s.sent} TXs', Icons.arrow_upward),
        _buildStatCard('Received', '${s.received} TXs', Icons.arrow_downward),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: widget.theme.accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 4),
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

  Widget _buildBreakdown(List<TransactionBreakdown> breakdown) {
    return Column(
      children: breakdown.map((b) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: b.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${b.type}: ${b.count} (${b.percentage.toStringAsFixed(0)}%)',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeatmap(List<DailyActivity> daily) {
    final maxCount = daily.isEmpty ? 1 : daily.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: daily.take(20).map((d) {
        final intensity = maxCount > 0 ? d.count / maxCount : 0.0;
        final color = intensity < 0.33
            ? Colors.white.withValues(alpha: 0.2)
            : intensity < 0.66
                ? widget.theme.accentColor.withValues(alpha: 0.5)
                : widget.theme.accentColor;
        return Tooltip(
          message: '${d.date.day}/${d.date.month}: ${d.count} TXs',
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVolumeChart(List<DailyActivity> daily) {
    if (daily.isEmpty) return const SizedBox.shrink();
    final maxVol = daily.map((e) => e.volumeSol).reduce((a, b) => a > b ? a : b);
    final spots = daily.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.volumeSol);
    }).toList();
    if (spots.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 120,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxVol > 0 ? maxVol * 1.1 : 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: widget.theme.accentColor,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: widget.theme.accentColor.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildTopInteractions(List<InteractionStats> list) {
    return Column(
      children: list.map((i) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            i.displayName,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          subtitle: Text(
            '${i.count} TXs',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white54),
            onPressed: () async {
              final uri = Uri.parse('https://solscan.io/account/${i.address}');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            tooltip: 'View on Solscan',
          ),
        );
      }).toList(),
    );
  }
}
