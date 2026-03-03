import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

import '../services/error_logger.dart';
import '../services/mobile_wallet_adapter_service.dart';
import '../services/wallet_connect_service.dart';

void _logWallet(String message, [Object? detail]) {
  final line = '$message${detail != null ? ': $detail' : ''}';
  if (kDebugMode) {
    debugPrint('[WalletState] $line');
  }
  ErrorLogger.info('WalletState', line);
}

/// Wallet connection: Android uses Solana Mobile Wallet Adapter (MWA),
/// other platforms use WalletConnect v2.
/// See https://docs.solanamobile.com/mobile-wallet-adapter/overview and
/// https://docs.solanamobile.com/flutter/overview
class WalletState extends ChangeNotifier {
  final WalletConnectService _wc = WalletConnectService();
  final MobileWalletAdapterService _mwa = MobileWalletAdapterService();
  static bool _wcInitialized = false;

  bool get _useMwa => defaultTargetPlatform == TargetPlatform.android;

  WalletConnectService get walletConnectService => _wc;

  String? get publicKey {
    if (_useMwa) return _mwa.publicKeyBase58;
    return _wc.address;
  }

  bool get isConnected {
    if (_useMwa) return _mwa.isConnected;
    return _wc.isConnected;
  }

  /// Truncated address for UI (e.g. "7xKX...9mNp").
  String get truncatedAddress {
    final addr = publicKey;
    if (addr == null || addr.length < 10) return '—';
    return '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}';
  }

  /// Ensure WC client is initialized (non-Android only).
  Future<void> ensureInitialized() async {
    if (_useMwa) return;
    if (_wcInitialized) return;
    _wcInitialized = true;
    await _wc.init();
    notifyListeners();
  }

  /// Connect: on Android runs MWA (native wallet picker); else opens WalletConnect QR modal.
  Future<void> startConnect() async {
    _logWallet('startConnect()', 'useMwa=$_useMwa');
    if (_useMwa) {
      final ok = await _mwa.authorize();
      _logWallet('MWA authorize() result', ok);
      if (ok) notifyListeners();
      return;
    }
    await ensureInitialized();
  }

  /// After user approves in wallet (WalletConnect only). Call with session when QR flow completes.
  Future<void> onSessionApproved(dynamic session) async {
    if (_useMwa) return;
    if (session != null) {
      await _wc.setSession(session as SessionData);
    }
    notifyListeners();
  }

  /// Disconnect wallet.
  Future<void> disconnect() async {
    if (_useMwa) {
      await _mwa.deauthorize();
    } else {
      await _wc.disconnect();
    }
    notifyListeners();
  }

  /// Sign transaction (WalletConnect path; MWA has signTransactions on service).
  Future<String?> signTransaction({required String serializedTransaction}) async {
    if (_useMwa) return null; // Use MobileWalletAdapterService.signTransactions with Uint8List
    final topic = _wc.topic;
    if (topic == null) return null;
    return _wc.signTransaction(
      topic: topic,
      serializedTransaction: serializedTransaction,
    );
  }

  Future<String?> signAndSendTransaction({required String serializedTransaction}) async {
    if (_useMwa) return null;
    final topic = _wc.topic;
    if (topic == null) return null;
    return _wc.signAndSendTransaction(
      topic: topic,
      serializedTransaction: serializedTransaction,
    );
  }

  /// MWA: sign raw transaction payloads (Android).
  Future<List<Uint8List>> signTransactions(List<Uint8List> transactions) async {
    if (!_useMwa) return [];
    return _mwa.signTransactions(transactions);
  }

  /// MWA: sign and send transactions (Android). Returns list of tx signature strings (base58).
  Future<List<String>> signAndSendTransactions(List<Uint8List> transactions) async {
    if (!_useMwa) return [];
    return _mwa.signAndSendTransactions(transactions);
  }
}