import 'package:flutter/foundation.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

import 'error_logger.dart';
import 'storage_service.dart';

/// WalletConnect v2 service: init client, generate URI, handle session, sign transactions.
/// Get a project ID at https://cloud.walletconnect.com and set [projectId].
class WalletConnectService {
  static const String projectId = 'YOUR_PROJECT_ID'; // Replace with your WalletConnect Cloud project ID

  Web3App? _client;
  SessionData? _session;
  final StorageService _storage = StorageService();

  Web3App? get client => _client;
  SessionData? get session => _session;
  bool get isConnected => _session != null;

  /// Current session topic for requests.
  String? get topic => _session?.topic;

  /// Initialize WalletConnect client (call once, e.g. on app start).
  Future<void> init() async {
    if (_client != null) return;
    try {
      _client = await Web3App.createInstance(
        projectId: projectId,
        metadata: PairingMetadata(
          name: 'Daily Rabbit Confirmation',
          description: 'Daily crypto affirmations and Jupiter swaps',
          url: 'https://dailyrabbit.app',
          icons: ['https://avatars.githubusercontent.com/u/37784886'],
          redirect: Redirect(
            native: 'dailyrabbit://',
            universal: 'https://dailyrabbit.app',
          ),
        ),
      );
      await _restoreSession();
    } catch (e, st) {
      ErrorLogger.log('WalletConnectService.init', e, st);
    }
  }

  /// Restore session from storage if available.
  Future<void> _restoreSession() async {
    try {
      final topic = await _storage.getWalletConnectTopic();
      if (topic == null || topic.isEmpty) return;
      final sessions = _client?.getActiveSessions();
      if (sessions == null) return;
      for (final entry in sessions.entries) {
        if (entry.key == topic) {
          _session = entry.value;
          return;
        }
      }
    } catch (e, st) {
      ErrorLogger.log('WalletConnectService._restoreSession', e, st);
    }
  }

  /// Start connection and return ConnectResponse. Caller shows [response.uri] in QR,
  /// then awaits [response.session.future] for session approval.
  Future<ConnectResponse?> connect() async {
    if (_client == null) await init();
    if (_client == null) return null;
    try {
      final resp = await _client!.connect(
        optionalNamespaces: {
          'solana': RequiredNamespace(
            chains: ['solana:5eykt4SsFvkVJjNakEsJ1DkzwTdwdh7tYN44tdQyeL'],
            methods: [
              'solana_signTransaction',
              'solana_signAllTransactions',
              'solana_signMessage',
              'solana_signAndSendTransaction',
            ],
            events: ['accountsChanged'],
          ),
          'eip155': RequiredNamespace(
            chains: ['eip155:1'],
            methods: ['personal_sign', 'eth_sendTransaction'],
            events: ['accountsChanged'],
          ),
        },
      );
      return resp;
    } catch (e, st) {
      ErrorLogger.log('WalletConnectService.connect', e, st);
      return null;
    }
  }

  /// Store session after user approves in wallet (call when session.future completes).
  Future<void> setSession(SessionData? session) async {
    _session = session;
    await _storage.setWalletConnectTopic(session?.topic);
  }

  /// Get first Solana account from session, or first EIP155 account as fallback.
  String? get address {
    if (_session == null) return null;
    try {
      final namespaces = _session!.namespaces;
      final solana = namespaces['solana'];
      if (solana?.accounts != null && solana!.accounts!.isNotEmpty) {
        final acc = solana.accounts!.first;
        // Format: "solana:5eykt...:BASE58_PUBKEY"
        final parts = acc.split(':');
        if (parts.length >= 3) return parts.last;
        return acc;
      }
      final eip155 = namespaces['eip155'];
      if (eip155?.accounts != null && eip155!.accounts!.isNotEmpty) {
        final acc = eip155.accounts!.first;
        final parts = acc.split(':');
        if (parts.length >= 3) return parts.last;
        return acc;
      }
    } catch (_) {}
    return null;
  }

  /// Disconnect and clear session.
  Future<void> disconnect() async {
    if (_session != null && _client != null) {
      try {
        await _client!.disconnectSession(
          topic: _session!.topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
      } catch (e, st) {
        ErrorLogger.log('WalletConnectService.disconnect', e, st);
      }
    }
    _session = null;
    await _storage.setWalletConnectTopic(null);
  }

  /// Sign a transaction via WalletConnect. Wallet app will prompt user.
  /// [serializedTransaction] is base64-encoded Solana transaction.
  /// Returns signed transaction (base64) or null if rejected/error.
  Future<String?> signTransaction({
    required String topic,
    required String serializedTransaction,
    String chainId = 'solana:5eykt4SsFvkVJjNakEsJ1DkzwTdwdh7tYN44tdQyeL',
  }) async {
    if (_client == null) return null;
    try {
      final result = await _client!.request(
        topic: topic,
        chainId: chainId,
        request: SessionRequestParams(
          method: 'solana_signTransaction',
          params: {'message': serializedTransaction},
        ),
      );
      if (result is String) return result;
      if (result is Map && result.containsKey('signature')) {
        return result['signature'] as String?;
      }
      return result?.toString();
    } catch (e, st) {
      ErrorLogger.log('WalletConnectService.signTransaction', e, st);
      return null;
    }
  }

  /// Sign and send transaction: request wallet to sign and submit to Solana network.
  Future<String?> signAndSendTransaction({
    required String topic,
    required String serializedTransaction,
    String chainId = 'solana:5eykt4SsFvkVJjNakEsJ1DkzwTdwdh7tYN44tdQyeL',
  }) async {
    if (_client == null) return null;
    try {
      final result = await _client!.request(
        topic: topic,
        chainId: chainId,
        request: SessionRequestParams(
          method: 'solana_signAndSendTransaction',
          params: {'message': serializedTransaction},
        ),
      );
      if (result is String) return result;
      if (result is Map && result.containsKey('signature')) {
        return result['signature'] as String?;
      }
      return result?.toString();
    } catch (e, st) {
      ErrorLogger.log('WalletConnectService.signAndSendTransaction', e, st);
      return null;
    }
  }
}
