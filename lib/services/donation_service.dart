import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:solana/dto.dart' show Encoding;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

import 'error_logger.dart';
import '../providers/wallet_state.dart';

/// Recipient address for donations. MUST be your project's real Solana wallet (base58).
/// Do not use the system program (1111...); wallets cannot simulate that and show "Unknown".
const String donationRecipientBase58 = '4bjTEWMmcoYVZ86zn6Jb49ERi4FMfZU6wXCTimPhNBpt';

/// Placeholder: if this address is set, we don't send (wallet can't recognize it).
const String _donationPlaceholder = '11111111111111111111111111111111';

const int lamportsPerSol = 1000000000;

/// SOL → lamports as integer, avoiding float error (0.01 → 10_000_000).
int _solToLamports(double sol) {
  if (sol <= 0 || !sol.isFinite) return 0;
  return (sol * lamportsPerSol).round();
}

/// Builds and sends a SOL donation transaction via [WalletState].
class DonationService {
  static const String _mainnetRpc = 'https://api.mainnet-beta.solana.com';

  final RpcClient _rpc = RpcClient(_mainnetRpc);

  /// Sends [solAmount] SOL from the connected wallet to the donation address.
  /// [solAmount] must be a positive number (e.g. 0.01, 0.02).
  /// Returns transaction signature on success.
  Future<String> sendDonation({
    required WalletState walletState,
    required double solAmount,
  }) async {
    final walletPublicKeyBase58 = walletState.publicKey;
    if (walletPublicKeyBase58 == null || walletPublicKeyBase58.isEmpty) {
      throw Exception('Wallet not connected');
    }
    if (solAmount <= 0 || !solAmount.isFinite) {
      throw Exception('Amount must be positive');
    }
    if (donationRecipientBase58 == _donationPlaceholder) {
      throw Exception('Donation is not available. Recipient address is not configured.');
    }

    // Lamports as integer (e.g. 0.01 SOL = 10_000_000 lamports)
    final lamports = _solToLamports(solAmount);
    if (lamports <= 0) throw Exception('Amount must be positive');
    final payer = Ed25519HDPublicKey.fromBase58(walletPublicKeyBase58);
    final recipient = Ed25519HDPublicKey.fromBase58(donationRecipientBase58);

    // Memo FIRST so wallet may show it prominently at sign time (amount visible before signing).
    final amountStr = solAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    final memoText = 'Sending $amountStr SOL - Donation to Daily Rabbit';
    final message = Message(
      instructions: [
        MemoInstruction(signers: [payer], memo: memoText),
        SystemInstruction.transfer(
          fundingAccount: payer,
          recipientAccount: recipient,
          lamports: lamports,
        ),
      ],
    );

    final blockhashResult =
        await _rpc.getLatestBlockhash(commitment: Commitment.confirmed);
    final recentBlockhash = blockhashResult.value.blockhash;

    // Legacy format: some wallets (e.g. Solana Seeker) decode and display SOL amount correctly.
    // compileV0 can show "No change" in wallet UI despite correct transfer.
    final compiled = message.compile(
      recentBlockhash: recentBlockhash,
      feePayer: payer,
    );

    final placeholderSig = Signature(List.filled(64, 0), publicKey: payer);
    final unsignedTx = SignedTx(
      signatures: [placeholderSig],
      compiledMessage: compiled,
    );
    final unsignedTxBytes =
        Uint8List.fromList(unsignedTx.toByteArray().toList());

    final useMwa = defaultTargetPlatform == TargetPlatform.android;
    if (useMwa) {
      final sentSigs =
          await walletState.signAndSendTransactions([unsignedTxBytes]);
      if (sentSigs.isNotEmpty) return sentSigs.first;
      final signed = await walletState.signTransactions([unsignedTxBytes]);
      if (signed.isEmpty) throw Exception('Sign rejected');
      final signedB64 = base64Encode(signed.first);
      return await _rpc.sendTransaction(
        signedB64,
        encoding: Encoding.base64,
        preflightCommitment: Commitment.confirmed,
      );
    }

    final b64 = base64Encode(unsignedTxBytes);
    final sig = await walletState.signAndSendTransaction(
      serializedTransaction: b64,
    );
    if (sig == null || sig.isEmpty) throw Exception('Sign/send failed');
    return sig;
  }
}
