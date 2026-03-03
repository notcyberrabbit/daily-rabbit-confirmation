import 'package:solana/solana.dart';

import '../models/on_chain_activity.dart';
import 'error_logger.dart';

/// Fetches on-chain transaction data for analytics dashboard.
class BlockchainAnalyticsService {
  static const String _rpcUrl = 'https://api.mainnet-beta.solana.com';

  final RpcClient _rpc = RpcClient(_rpcUrl, timeout: const Duration(seconds: 20));
  final Map<String, _CachedData> _cache = {};
  static const _cacheExpiry = Duration(minutes: 5);

  /// Fetch full activity data for a period.
  /// [startDate] and [endDate] optionally narrow the range (inclusive).
  Future<OnChainActivityData> fetchActivity(
    String walletAddress,
    int days, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final cacheKey = '${walletAddress}_${days}_${startDate?.millisecondsSinceEpoch ?? 0}_${endDate?.millisecondsSinceEpoch ?? 0}';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    try {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final limit = days <= 7 ? 100 : (days <= 14 ? 200 : 500);
      final maxRequests = days <= 7 ? 2 : (days <= 14 ? 4 : 6);

      final allSigs = <dynamic>[];
      String? before;
      for (var r = 0; r < maxRequests; r++) {
        final sigs = await _rpc.getSignaturesForAddress(
          walletAddress,
          limit: limit,
          before: before,
        );
        if (sigs.isEmpty) break;
        allSigs.addAll(sigs);
        if (sigs.length < limit) break;
        before = sigs.last.signature;
        final lastBt = sigs.last.blockTime;
        if (lastBt != null) {
          final lastDt = DateTime.fromMillisecondsSinceEpoch(lastBt * 1000);
          if (lastDt.isBefore(cutoff)) break;
        }
      }

      if (allSigs.isEmpty) {
        final empty = OnChainActivityData.empty(days, startDate: startDate, endDate: endDate);
        _cache[cacheKey] = _CachedData(empty);
        return empty;
      }

      // Filter by blockTime (if available) and optional date range
      final filtered = allSigs.where((s) {
        final bt = s.blockTime;
        if (bt == null) return true;
        final dt = DateTime.fromMillisecondsSinceEpoch(bt * 1000);
        if (dt.isBefore(cutoff)) return false;
        if (startDate != null) {
          final start = DateTime(startDate.year, startDate.month, startDate.day);
          if (dt.isBefore(start)) return false;
        }
        if (endDate != null) {
          final end = DateTime(endDate.year, endDate.month, endDate.day).add(const Duration(days: 1));
          if (dt.isAfter(end)) return false;
        }
        return true;
      }).toList();

      if (filtered.isEmpty) {
        final empty = OnChainActivityData.empty(days, startDate: startDate, endDate: endDate);
        _cache[cacheKey] = _CachedData(empty);
        return empty;
      }

      // Simplified: count all as "other" for now (full parsing would need getTransaction per tx)
      final total = filtered.length;
      final breakdown = [
        _buildBreakdown('Other', total, total),
      ];

      final dailyMap = <DateTime, ({int count, double volume})>{};
      final hourlyCounts = List<int>.filled(24, 0);
      for (final s in filtered) {
        final bt = s.blockTime;
        DateTime day;
        int hour = 12;
        if (bt != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(bt * 1000);
          day = DateTime(dt.year, dt.month, dt.day);
          hour = dt.hour;
        } else {
          day = DateTime.now();
          day = DateTime(day.year, day.month, day.day);
        }
        final cur = dailyMap[day] ?? (count: 0, volume: 0.0);
        dailyMap[day] = (count: cur.count + 1, volume: cur.volume);
        if (hour >= 0 && hour < 24) hourlyCounts[hour]++;
      }

      final transactions = filtered.map((s) {
        final bt = s.blockTime;
        return TransactionItem(
          signature: s.signature,
          blockTime: bt != null
              ? DateTime.fromMillisecondsSinceEpoch(bt * 1000)
              : null,
          hasError: s.err != null,
        );
      }).toList();

      final daily = dailyMap.entries
          .map((e) => DailyActivity(
                date: e.key,
                count: e.value.count,
                volumeSol: e.value.volume,
              ))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final dailyCounts = daily.map((e) => e.count).toList();
      final maxTxPerDay = dailyCounts.isEmpty ? 0 : dailyCounts.reduce((a, b) => a > b ? a : b);
      final minTxPerDay = dailyCounts.isEmpty
          ? 0
          : dailyCounts.reduce((a, b) => a < b ? a : b);

      final dataTruncated = allSigs.length >= limit * maxRequests;

      final topInteractions = <InteractionStats>[];

      final summary = TransactionSummary(
        total: total,
        volumeSol: 0,
        sent: total ~/ 2,
        received: total - (total ~/ 2),
        maxTxPerDay: maxTxPerDay,
        minTxPerDay: minTxPerDay,
      );

      final data = OnChainActivityData(
        summary: summary,
        breakdown: breakdown,
        dailyActivity: daily,
        topInteractions: topInteractions.take(5).toList(),
        periodDays: days,
        transactions: transactions,
      );

      _cache[cacheKey] = _CachedData(data);
      return data;
    } catch (e, st) {
      ErrorLogger.log('BlockchainAnalyticsService.fetchActivity', e, st);
      rethrow;
    }
  }

  TransactionBreakdown _buildBreakdown(String type, int count, int total) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    final color = switch (type) {
      'Transfer' => TxTypeColors.transfer,
      'Swap' => TxTypeColors.swap,
      'Stake' => TxTypeColors.stake,
      'NFT' => TxTypeColors.nft,
      _ => TxTypeColors.other,
    };
    return TransactionBreakdown(type: type, count: count, percentage: pct, color: color);
  }

  void clearCache() => _cache.clear();
}

class _CachedData {
  final OnChainActivityData data;
  final DateTime _expiry = DateTime.now().add(BlockchainAnalyticsService._cacheExpiry);

  _CachedData(this.data);
  bool get isExpired => DateTime.now().isAfter(_expiry);
}

/// Full activity data for the dashboard.
class OnChainActivityData {
  final TransactionSummary summary;
  final List<TransactionBreakdown> breakdown;
  final List<DailyActivity> dailyActivity;
  final List<InteractionStats> topInteractions;
  final List<TransactionItem> transactions;
  final int periodDays;
  final DateTime? startDate;
  final DateTime? endDate;
  /// TX count per hour (0-23).
  final List<int> hourlyDistribution;
  /// True when RPC limit reached, data may be incomplete.
  final bool dataTruncated;

  OnChainActivityData({
    required this.summary,
    required this.breakdown,
    required this.dailyActivity,
    required this.topInteractions,
    required this.transactions,
    required this.periodDays,
    this.startDate,
    this.endDate,
    this.hourlyDistribution = const [],
    this.dataTruncated = false,
  });

  factory OnChainActivityData.empty(
    int days, {
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      OnChainActivityData(
        summary: TransactionSummary.empty,
        breakdown: [],
        dailyActivity: [],
        topInteractions: [],
        transactions: [],
        periodDays: days,
        startDate: startDate,
        endDate: endDate,
      );
}
