import 'package:solana/dto.dart' show Encoding, TokenAccountsFilter;
import 'package:solana/solana.dart';

/// Fetches SOL and SPL token balances for a wallet (mainnet).
class WalletBalanceService {
  static const String _rpcUrl = 'https://api.mainnet-beta.solana.com';

  static const String usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
  static const String bonkMint = 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263';
  static const String jupMint = 'JUPyiwrYJFskUPiHa7hkeR8VUtAeFoSYbKedZNsDvCN';

  final RpcClient _rpc = RpcClient(_rpcUrl, timeout: const Duration(seconds: 15));

  /// SOL balance in lamports.
  Future<int> getSolBalance(String ownerBase58) async {
    try {
      final result = await _rpc.getBalance(ownerBase58);
      return result.value;
    } catch (_) {
      return 0;
    }
  }

  /// Token balance as display string (e.g. "1.5") or "0" if no account.
  Future<String> getTokenBalance(String ownerBase58, String mint) async {
    try {
      final accounts = await _rpc.getTokenAccountsByOwner(
        ownerBase58,
        TokenAccountsFilter.byMint(mint),
        encoding: Encoding.jsonParsed,
      );
      if (accounts.value.isEmpty) return '0';
      final ataPubkey = accounts.value.first.pubkey;
      final balance = await _rpc.getTokenAccountBalance(ataPubkey);
      return balance.value.uiAmountString ?? '0';
    } catch (_) {
      return '0';
    }
  }

  /// Fetches SOL + USDC, BONK, JUP. Amounts as display strings.
  Future<WalletBalances> fetchBalances(String ownerBase58) async {
    final solLamports = await getSolBalance(ownerBase58);
    final solAmount = solLamports / lamportsPerSol;
    final usdc = await getTokenBalance(ownerBase58, usdcMint);
    final bonk = await getTokenBalance(ownerBase58, bonkMint);
    final jup = await getTokenBalance(ownerBase58, jupMint);
    return WalletBalances(
      solLamports: solLamports,
      solFormatted: _formatSol(solAmount),
      usdc: usdc,
      bonk: bonk,
      jup: jup,
    );
  }
}

String _formatSol(double v) {
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)}k';
  if (v >= 1) return v.toStringAsFixed(2);
  if (v >= 0.01) return v.toStringAsFixed(4);
  return v.toStringAsFixed(6);
}

class WalletBalances {
  final int solLamports;
  final String solFormatted;
  final String usdc;
  final String bonk;
  final String jup;

  WalletBalances({
    required this.solLamports,
    required this.solFormatted,
    required this.usdc,
    required this.bonk,
    required this.jup,
  });
}
