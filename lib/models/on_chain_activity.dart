import 'package:flutter/material.dart';

/// Summary of transaction stats for a period.
class TransactionSummary {
  final int total;
  final double volumeSol;
  final int sent;
  final int received;
  /// Max TX count in a single day in the period.
  final int maxTxPerDay;
  /// Min TX count in a single day (among days with activity).
  final int minTxPerDay;

  const TransactionSummary({
    required this.total,
    required this.volumeSol,
    required this.sent,
    required this.received,
    required this.maxTxPerDay,
    required this.minTxPerDay,
  });

  static const empty = TransactionSummary(
    total: 0,
    volumeSol: 0,
    sent: 0,
    received: 0,
    maxTxPerDay: 0,
    minTxPerDay: 0,
  );
}

/// Transaction type breakdown with count and percentage.
class TransactionBreakdown {
  final String type;
  final int count;
  final double percentage;
  final Color color;

  const TransactionBreakdown({
    required this.type,
    required this.count,
    required this.percentage,
    required this.color,
  });
}

/// Daily activity for heatmap and volume chart.
class DailyActivity {
  final DateTime date;
  final int count;
  final double volumeSol;

  const DailyActivity({
    required this.date,
    required this.count,
    required this.volumeSol,
  });
}

/// Top interaction (counterparty) stats.
class InteractionStats {
  final String address;
  final String displayName;
  final int count;
  final String type;

  const InteractionStats({
    required this.address,
    required this.displayName,
    required this.count,
    required this.type,
  });
}

/// Transaction type for UI icons.
enum TxDisplayType {
  swap,
  send,
  receive,
  nftMint,
  contract,
  unknown,
}

/// Single transaction for details list.
class TransactionItem {
  final String signature;
  final DateTime? blockTime;
  final bool? hasError;
  final TxDisplayType type;
  final String? actionLabel;
  final double? amountSol;
  final bool? isIncoming;
  final String? protocol;

  const TransactionItem({
    required this.signature,
    this.blockTime,
    this.hasError,
    this.type = TxDisplayType.unknown,
    this.actionLabel,
    this.amountSol,
    this.isIncoming,
    this.protocol,
  });
}

/// Transaction type colors.
class TxTypeColors {
  static const transfer = Color(0xFF4A90E2);
  static const swap = Color(0xFF4CAF50);
  static const stake = Color(0xFFFFC107);
  static const nft = Color(0xFF9C27B0);
  static const other = Color(0xFF9E9E9E);
}
