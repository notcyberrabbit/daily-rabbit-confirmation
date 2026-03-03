import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:solana/dto.dart' show Encoding;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'error_logger.dart';
import '../providers/wallet_state.dart';

/// Memo program ID (SPL Memo).
const String memoProgramId = 'MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr';

/// Cost estimate for a memo tx (~5000 lamports).
const int estimatedLamports = 5000;

/// Max memo length (SPL memo limit).
const int maxMemoBytes = 566;

/// Format: "Daily Rabbit | 2026-02-11 09:30 | {affirmation_text}"
String formatMemo(String affirmationText, DateTime dateTime) {
  final dateStr =
      '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  final memo = 'Daily Rabbit | $dateStr | $affirmationText';
  if (memo.length > maxMemoBytes) {
    return 'Daily Rabbit | $dateStr | ${affirmationText.substring(0, maxMemoBytes - dateStr.length - 20)}…';
  }
  return memo;
}

/// Result of recording an affirmation on-chain.
class RecordAffirmationResult {
  final String signature;

  RecordAffirmationResult({required this.signature});
}

/// One on-chain memo record (from history).
class OnChainMemoRecord {
  final String signature;
  final String memo;
  final DateTime? blockTime;

  OnChainMemoRecord({
    required this.signature,
    required this.memo,
    this.blockTime,
  });
}

/// Records affirmations on Solana via Memo program and fetches history.
/// Uses [WalletState] for signing: MWA on Android (sign + send via RPC) or WalletConnect signAndSend elsewhere.
class OnChainAffirmationService {
  static const String _mainnetRpc = 'https://api.mainnet-beta.solana.com';

  final RpcClient _rpc = RpcClient(_mainnetRpc);

  /// Records an affirmation on-chain. [walletState] must be connected.
  /// Returns signature on success, throws on failure.
  Future<RecordAffirmationResult> recordAffirmation({
    required WalletState walletState,
    required String affirmationText,
  }) async {
    final walletPublicKeyBase58 = walletState.publicKey;
    if (walletPublicKeyBase58 == null || walletPublicKeyBase58.isEmpty) {
      throw Exception('Wallet not connected');
    }
    final memo = formatMemo(affirmationText, DateTime.now());
    final payer = Ed25519HDPublicKey.fromBase58(walletPublicKeyBase58);

    final message = Message.only(
      MemoInstruction(signers: [payer], memo: memo),
    );

    final blockhashResult =
        await _rpc.getLatestBlockhash(commitment: Commitment.confirmed);
    final recentBlockhash = blockhashResult.value.blockhash;

    final compiled = message.compile(
      recentBlockhash: recentBlockhash,
      feePayer: payer,
    );

    // Unsigned tx for wallet: placeholder signature + compiled message (same as Flutter MWA example).
    final placeholderSig = Signature(List.filled(64, 0), publicKey: payer);
    final unsignedTx = SignedTx(
      signatures: [placeholderSig],
      compiledMessage: compiled,
    );
    final unsignedTxBytes = Uint8List.fromList(unsignedTx.toByteArray().toList());

    final useMwa = defaultTargetPlatform == TargetPlatform.android;
    if (useMwa) {
      // Prefer signAndSendTransactions so the wallet signs and submits; often more reliable than sign + RPC.
      final sentSigs = await walletState.signAndSendTransactions([unsignedTxBytes]);
      if (sentSigs.isNotEmpty) {
        return RecordAffirmationResult(signature: sentSigs.first);
      }
      // Fallback: sign only then send via RPC
      final signed = await walletState.signTransactions([unsignedTxBytes]);
      if (signed.isEmpty) {
        throw Exception('Sign rejected');
      }
      final signedB64 = base64Encode(signed.first);
      final signature = await _rpc.sendTransaction(
        signedB64,
        encoding: Encoding.base64,
        preflightCommitment: Commitment.confirmed,
      );
      return RecordAffirmationResult(signature: signature);
    }

    final b64 = base64Encode(unsignedTxBytes);
    final sig = await walletState.signAndSendTransaction(
      serializedTransaction: b64,
    );
    if (sig == null || sig.isEmpty) {
      throw Exception('Sign/send failed');
    }
    return RecordAffirmationResult(signature: sig);
  }

  /// Fetches memo transactions for the given address (recent first).
  Future<List<OnChainMemoRecord>> getOnChainHistory(
    String walletPublicKeyBase58,
  ) async {
    final list = <OnChainMemoRecord>[];
    try {
      final sigs = await _rpc.getSignaturesForAddress(
        walletPublicKeyBase58,
        limit: 50,
        commitment: Commitment.confirmed,
      );
      for (final info in sigs) {
        final blockTime = info.blockTime != null
            ? DateTime.fromMillisecondsSinceEpoch(info.blockTime! * 1000)
            : null;
        final memo = info.memo;
        if (memo != null && memo.isNotEmpty) {
          list.add(OnChainMemoRecord(
            signature: info.signature,
            memo: memo,
            blockTime: blockTime,
          ));
          continue;
        }
        final tx = await _rpc.getTransaction(
          info.signature,
          commitment: Commitment.confirmed,
        );
        final parsed = tx != null ? _extractMemoFromTransaction(tx) : null;
        if (parsed != null && parsed.isNotEmpty) {
          list.add(OnChainMemoRecord(
            signature: info.signature,
            memo: parsed,
            blockTime: blockTime,
          ));
        }
      }
    } catch (e, st) {
      ErrorLogger.log('OnChainAffirmationService.getOnChainHistory', e, st);
    }
    return list;
  }

  String? _extractMemoFromTransaction(dynamic tx) {
    try {
      final decoded = tx.transaction;
      if (decoded == null) return null;
      final message = decoded.message;
      if (message == null) return null;
      final instructions = message.instructions as List<dynamic>?;
      if (instructions == null) return null;
      for (final ix in instructions) {
        final programId = ix.programId?.toString() ?? ix.programIdBase58?.toString();
        if (programId == memoProgramId) {
          final data = ix.data ?? ix.parsed;
          if (data is String) return data;
          if (data != null) {
            try {
              final bytes = base64Decode(data as String);
              return utf8.decode(bytes);
            } catch (_) {}
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
