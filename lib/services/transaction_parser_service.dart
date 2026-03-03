import 'package:solana/solana.dart';

import '../models/on_chain_activity.dart';

/// Known program IDs for type detection.
const _systemProgram = '11111111111111111111111111111111';
const _jupiterV6 = 'JUP6LkbZbjS1jKKwapdHNy74zcZ3tLUZoi5QNyVTaV4';
const _raydiumAmm = '675kPX9MHTjS2zt1qfr1NYHuzeLXfQM9H24wFSUt1Mp8';
const _metaplexNft = 'metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s';

/// Parses transaction details for display. Fetches getTransaction and extracts type, amount, protocol.
class TransactionParserService {
  final RpcClient _rpc = RpcClient(
    'https://api.mainnet-beta.solana.com',
    timeout: const Duration(seconds: 8),
  );

  /// Enrich transaction items with parsed data. Limits to [maxToFetch] to avoid timeouts.
  Future<List<TransactionItem>> enrichTransactions({
    required List<TransactionItem> items,
    required String walletAddress,
    int maxToFetch = 25,
  }) async {
    final results = <TransactionItem>[];
    for (var i = 0; i < items.length && i < maxToFetch; i++) {
      final item = items[i];
      try {
        final tx = await _rpc.getTransaction(
          item.signature,
          commitment: Commitment.confirmed,
        );
        if (tx != null) {
          results.add(_parseTransaction(tx, item, walletAddress));
        } else {
          results.add(item);
        }
      } catch (_) {
        results.add(item);
      }
    }
    results.addAll(items.skip(results.length));
    return results;
  }

  TransactionItem _parseTransaction(
    dynamic tx,
    TransactionItem item,
    String walletAddress,
  ) {
    TxDisplayType type = TxDisplayType.unknown;
    String? actionLabel;
    double? amountSol;
    bool? isIncoming;
    String? protocol;

    try {
      final meta = tx.meta;
      final decoded = tx.transaction;
      if (decoded == null) return item;

      final message = decoded.message;
      if (message == null) return item;

      final accountKeys = message.accountKeys;
      final instructions = message.instructions ?? message.compiledInstructions ?? [];
      final walletIndex = _findAccountIndex(accountKeys, walletAddress);

      double balanceChange = 0;
      if (meta != null && walletIndex >= 0) {
        final pre = meta.preBalances as List<dynamic>?;
        final post = meta.postBalances as List<dynamic>?;
        if (pre != null && post != null && walletIndex < pre.length && walletIndex < post.length) {
          final preBal = (pre[walletIndex] is int) ? pre[walletIndex] as int : 0;
          final postBal = (post[walletIndex] is int) ? post[walletIndex] as int : 0;
          balanceChange = (postBal - preBal) / 1e9;
          isIncoming = balanceChange > 0;
          amountSol = balanceChange.abs();
        }
      }

      final programIds = <String>{};
      for (final ix in instructions) {
        final pid = ix.programId?.toString() ?? ix.programIdBase58 ?? '';
        if (pid.isNotEmpty) programIds.add(pid);
      }

      if (programIds.contains(_jupiterV6)) {
        type = TxDisplayType.swap;
        protocol = 'Jupiter';
        actionLabel = amountSol != null
            ? 'Swapped ${amountSol.toStringAsFixed(4)} SOL'
            : 'Swap';
      } else if (programIds.contains(_raydiumAmm)) {
        type = TxDisplayType.swap;
        protocol = 'Raydium';
        actionLabel = amountSol != null
            ? 'Swapped ${amountSol.toStringAsFixed(4)} SOL'
            : 'Swap';
      } else if (programIds.contains(_metaplexNft)) {
        type = TxDisplayType.nftMint;
        protocol = 'Metaplex';
        actionLabel = 'NFT Mint';
      } else if (programIds.contains(_systemProgram) && programIds.length <= 2) {
        type = isIncoming == true ? TxDisplayType.receive : TxDisplayType.send;
        actionLabel = amountSol != null
            ? (isIncoming == true
                ? 'Received ${amountSol.toStringAsFixed(4)} SOL'
                : 'Sent ${amountSol.toStringAsFixed(4)} SOL')
            : (isIncoming == true ? 'Received SOL' : 'Sent SOL');
      } else if (programIds.length > 1) {
        type = TxDisplayType.contract;
        actionLabel = amountSol != null
            ? 'Interaction ${amountSol >= 0 ? '+' : ''}${amountSol.toStringAsFixed(4)} SOL'
            : 'Contract Interaction';
      } else {
        actionLabel = amountSol != null
            ? '${amountSol >= 0 ? "+" : ""}${amountSol.toStringAsFixed(4)} SOL'
            : 'Transaction';
      }
    } catch (_) {}

    return TransactionItem(
      signature: item.signature,
      blockTime: item.blockTime,
      hasError: item.hasError,
      type: type,
      actionLabel: actionLabel ?? 'Transaction',
      amountSol: amountSol,
      isIncoming: isIncoming,
      protocol: protocol,
    );
  }

  int _findAccountIndex(dynamic accountKeys, String address) {
    if (accountKeys == null) return -1;
    final list = accountKeys is List ? accountKeys : (accountKeys as Iterable).toList();
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      final addr = item is String ? item : (item.pubkey?.toString() ?? item.toString());
      if (addr == address) return i;
    }
    return -1;
  }
}
