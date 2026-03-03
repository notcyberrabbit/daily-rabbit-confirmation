import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:solana/base58.dart';
import 'package:solana/solana.dart';
import 'package:solana_mobile_client/solana_mobile_client.dart';

import 'error_logger.dart';

/// Detailed MWA logs: debug console + Error logs screen (Settings).
void _log(String message, [Object? detail]) {
  final line = '$message${detail != null ? ': $detail' : ''}';
  if (kDebugMode) {
    debugPrint('[MWA] $line');
  }
  ErrorLogger.info('MWA', line);
}

/// Solana Mobile Wallet Adapter (MWA) integration per
/// https://docs.solanamobile.com/mobile-wallet-adapter/overview
/// and https://docs.solanamobile.com/flutter/overview
///
/// Android only; enables connect via native wallet picker (Phantom, etc.).
class MobileWalletAdapterService {
  String? _authToken;
  Uint8List? _publicKeyBytes;

  bool get isConnected => _authToken != null && _publicKeyBytes != null;

  /// Base58 public key for display and signing.
  String? get publicKeyBase58 {
    if (_publicKeyBytes == null) return null;
    try {
      return Ed25519HDPublicKey(_publicKeyBytes!).toBase58();
    } catch (e, st) {
      ErrorLogger.log('MobileWalletAdapterService.publicKeyBase58', e, st);
      return null;
    }
  }

  String? get authToken => _authToken;

  /// Authorize (connect) wallet: opens native wallet picker (e.g. Solana Seeker), user approves.
  /// Per Solana Mobile Flutter example: do NOT await startActivityForResult - fire intent then session.start().
  /// https://docs.solanamobile.com/flutter/overview
  Future<bool> authorize() async {
    _log('authorize() started');
    try {
      _log('Creating LocalAssociationScenario');
      final session = await LocalAssociationScenario.create();
      _log('Scenario created, firing startActivityForResult (wallet picker intent)');
      session.startActivityForResult(null).ignore();

      _log('Waiting for session.start() (wallet must connect back)');
      final client = await session.start();
      _log('Session started, calling client.authorize()');
      // AppIdentity per Flutter example & Android docs: iconUri relative to identityUri.
      // Use known-good identity for testing if wallet keeps rejecting (e.g. unregistered dApp).
      const useKnownGoodIdentity = bool.fromEnvironment('MWA_USE_SOLANA_IDENTITY', defaultValue: false);
      final identityUri = useKnownGoodIdentity ? Uri.parse('https://solana.com') : Uri.parse('https://dailyrabbit.app');
      final result = await client.authorize(
        identityUri: identityUri,
        iconUri: Uri.parse('favicon.ico'), // relative → identityUri + /favicon.ico
        identityName: useKnownGoodIdentity ? 'Solana' : 'Daily Rabbit',
        cluster: 'mainnet-beta',
      );
      _log('authorize() returned', result != null ? 'OK' : 'null (cancelled/rejected)');
      await session.close();
      _log('Session closed');

      if (result != null) {
        _authToken = result.authToken;
        _publicKeyBytes = result.publicKey;
        _log('Stored authToken and publicKey', publicKeyBase58);
        return true;
      }
      _log('No result: user cancelled or wallet rejected');
      return false;
    } catch (e, st) {
      _log('authorize() threw', e);
      ErrorLogger.log('MobileWalletAdapterService.authorize', e, st);
      return false;
    }
  }

  /// Check if any MWA-compatible wallet (e.g. Solana Seeker) is installed.
  static Future<bool> isWalletAvailable() async {
    _log('isWalletAvailable() checking...');
    try {
      final available = await LocalAssociationScenario.isAvailable();
      _log('isWalletAvailable()', available);
      return available;
    } catch (e, st) {
      _log('isWalletAvailable() error', e);
      ErrorLogger.log('MobileWalletAdapterService.isWalletAvailable', e, st);
      return false;
    }
  }

  /// Deauthorize (disconnect) wallet.
  Future<void> deauthorize() async {
    _log('deauthorize()', _authToken != null ? 'has token' : 'no token');
    if (_authToken == null) return;
    try {
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      await client.deauthorize(authToken: _authToken!);
      await session.close();
      _log('deauthorize() done');
    } catch (e, st) {
      _log('deauthorize() error', e);
      ErrorLogger.log('MobileWalletAdapterService.deauthorize', e, st);
    } finally {
      _authToken = null;
      _publicKeyBytes = null;
    }
  }

  /// Reauthorize in current session so wallet shows sign UI (required before sign/signAndSend per MWA example).
  Future<bool> _reauthorize(MobileWalletAdapterClient client) async {
    if (_authToken == null) {
      _log('_reauthorize() skipped', 'no auth token (connect first)');
      return false;
    }
    try {
      const useKnownGoodIdentity = bool.fromEnvironment('MWA_USE_SOLANA_IDENTITY', defaultValue: false);
      final identityUri = useKnownGoodIdentity ? Uri.parse('https://solana.com') : Uri.parse('https://dailyrabbit.app');
      final result = await client.reauthorize(
        identityUri: identityUri,
        iconUri: Uri.parse('favicon.ico'),
        identityName: useKnownGoodIdentity ? 'Solana' : 'Daily Rabbit',
        authToken: _authToken!,
      );
      final ok = result != null;
      _log('_reauthorize()', ok ? 'OK' : 'null (cancelled/rejected)');
      return ok;
    } catch (e, st) {
      _log('_reauthorize() error', e);
      ErrorLogger.log('MobileWalletAdapterService._reauthorize', e, st);
      return false;
    }
  }

  /// Sign transactions: opens wallet, user approves. Returns signed payloads or empty on reject.
  /// Calls reauthorize first so the wallet recognizes the app and shows the sign UI.
  Future<List<Uint8List>> signTransactions(List<Uint8List> transactions) async {
    _log('signTransactions()', 'count=${transactions.length}');
    try {
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      if (!await _reauthorize(client)) {
        await session.close();
        _log('signTransactions() aborted', 'reauthorize failed');
        return [];
      }
      final result = await client.signTransactions(transactions: transactions);
      await session.close();
      _log('signTransactions() done', 'signed=${result.signedPayloads.length}');
      return result.signedPayloads;
    } catch (e, st) {
      _log('signTransactions() error', e);
      ErrorLogger.log('MobileWalletAdapterService.signTransactions', e, st);
      return [];
    }
  }

  /// Sign and send transactions: wallet signs and submits to the network. Returns tx signatures (base58) or empty on reject.
  /// Calls reauthorize first so the wallet recognizes the app and shows the sign UI (fixes wallet not opening / timeout).
  Future<List<String>> signAndSendTransactions(List<Uint8List> transactions) async {
    _log('signAndSendTransactions()', 'count=${transactions.length}');
    try {
      final session = await LocalAssociationScenario.create();
      session.startActivityForResult(null).ignore();
      final client = await session.start();
      if (!await _reauthorize(client)) {
        await session.close();
        _log('signAndSendTransactions() aborted', 'reauthorize failed');
        return [];
      }
      final result = await client.signAndSendTransactions(transactions: transactions);
      await session.close();
      final sigs = result.signatures
          .map((bytes) => bytes.length == 64 ? base58encode(bytes) : null)
          .whereType<String>()
          .toList();
      _log('signAndSendTransactions() done', 'signatures=${sigs.length}');
      return sigs;
    } catch (e, st) {
      _log('signAndSendTransactions() error', e);
      ErrorLogger.log('MobileWalletAdapterService.signAndSendTransactions', e, st);
      return [];
    }
  }
}
