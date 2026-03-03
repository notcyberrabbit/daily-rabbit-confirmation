import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../providers/wallet_state.dart';
import '../services/error_logger.dart';

/// WebView that loads Jupiter Plugin (plugin.jup.ag) with wallet passthrough:
/// connect wallet in the app header; the plugin uses that wallet (no "Connect" inside WebView).
/// https://dev.jup.ag/tool-kits/plugin — enableWalletPassthrough.
class JupiterWebView extends StatefulWidget {
  final double height;
  final WalletState? walletState;
  final int recreateKey;

  const JupiterWebView({
    super.key,
    this.height = 400,
    this.walletState,
    this.recreateKey = 0,
  });

  @override
  State<JupiterWebView> createState() => _JupiterWebViewState();
}

class _JupiterWebViewState extends State<JupiterWebView> {
  static const String _referralAccount =
      'D5PfCHwrL1ng4iFufDfVbT7wWMZhEoB74Hc6HaemzMmi';
  static const String _solMint = 'So11111111111111111111111111111111111111112';
  static const String _usdcMint = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  late final WebViewController _controller;
  bool _loading = true;
  bool _jupiterReady = false;

  void _walletListener() {
    if (!mounted) return;
    final connected = widget.walletState?.isConnected == true;
    if (kDebugMode) debugPrint('[JupiterWebView] Wallet state changed, isConnected=$connected');
    if (connected && _jupiterReady) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _syncWalletToJupiter();
      });
    } else {
      _syncWalletToJupiter();
    }
  }

  static String _buildHtml() {
    return r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Jupiter Swap</title>
  <script src="https://plugin.jup.ag/plugin-v1.js"></script>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; height: 100%; width: 100%; overflow: hidden; background: #0d0d0d; }
    #jupiter-plugin { width: 100%; height: 100%; min-height: 400px; }
  </style>
</head>
<body>
  <div id="jupiter-plugin"></div>
  <script>
    (function() {
      var signNextId = 0;
      var signPending = {};
      function toBase64(u8) {
        var b = typeof u8.buffer !== "undefined" ? u8 : new Uint8Array(u8);
        var bin = String.fromCharCode.apply(null, b);
        return btoa(bin);
      }
      function fromBase64(str) {
        var bin = atob(str);
        var out = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
        return out;
      }
      var solana = window.solanaWeb3 || window["@solana/web3.js"];
      var PublicKey = solana && solana.PublicKey;
      var Transaction = solana && solana.Transaction;
      window.__bridgeWallet = {
        name: "App Wallet",
        publicKey: null,
        signTransaction: function(tx) {
          return new Promise(function(resolve, reject) {
            try {
              var raw = tx.serialize ? tx.serialize({ requireAllSignatures: false }) : (tx.serialize && tx.serialize());
              if (!raw || !raw.length) { reject(new Error("Could not serialize transaction")); return; }
              var id = (signNextId++).toString();
              signPending[id] = { resolve: resolve, reject: reject, tx: tx };
              var payload = toBase64(raw);
              if (window.FlutterBridge) {
                window.FlutterBridge.postMessage(JSON.stringify({ type: "sign", id: id, payload: payload }));
              } else {
                reject(new Error("Flutter bridge not ready"));
              }
            } catch (e) {
              reject(e);
            }
          });
        },
        signAllTransactions: function(txs) {
          return Promise.all(txs.map(function(tx) { return window.__bridgeWallet.signTransaction(tx); }));
        }
      };
      window.__onSignResult = function(id, signedB64, err) {
        var p = signPending[id];
        if (!p) return;
        delete signPending[id];
        if (err) { p.reject(new Error(err)); return; }
        try {
          var signedBuf = fromBase64(signedB64);
          var signedTx = Transaction && Transaction.from ? Transaction.from(signedBuf) : null;
          if (signedTx) p.resolve(signedTx); else p.resolve(p.tx);
        } catch (e) {
          p.reject(e);
        }
      };
      window.__setPassthroughWallet = function(pubkeyB58) {
        if (typeof window.Jupiter === "undefined" || !window.Jupiter.syncProps) return;
        if (!pubkeyB58) {
          window.Jupiter.syncProps({ passthroughWalletContextState: { wallet: null, publicKey: null, connected: false } });
          return;
        }
        var pk = PublicKey ? new PublicKey(pubkeyB58) : { toBase58: function() { return pubkeyB58; } };
        window.__bridgeWallet.publicKey = pk;
        window.Jupiter.syncProps({
          passthroughWalletContextState: {
            wallet: window.__bridgeWallet,
            publicKey: pk,
            connected: true
          }
        });
      };
      function initJupiter() {
        if (typeof window.Jupiter === "undefined") {
          setTimeout(initJupiter, 100);
          return;
        }
        window.Jupiter.init({
          displayMode: "integrated",
          integratedTargetId: "jupiter-plugin",
          enableWalletPassthrough: true,
          onRequestConnectWallet: function() {
            if (window.FlutterBridge) window.FlutterBridge.postMessage(JSON.stringify({ type: "requestConnect" }));
          },
          formProps: {
            initialInputMint: "placeholderSol",
            initialOutputMint: "placeholderUsdc",
            referralAccount: "placeholderReferral"
          },
          containerStyles: { width: "100%", height: "100%", borderRadius: "12px", overflow: "hidden" }
        });
        window.__jupiterReady = true;
        if (window.FlutterBridge) window.FlutterBridge.postMessage(JSON.stringify({ type: "jupiterReady" }));
      }
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", initJupiter);
      } else {
        initJupiter();
      }
    })();
  </script>
</body>
</html>
'''
        .replaceAll('placeholderReferral', _referralAccount)
        .replaceAll('placeholderSol', _solMint)
        .replaceAll('placeholderUsdc', _usdcMint);
  }

  void _syncWalletToJupiter() {
    final ws = widget.walletState;
    final pubKey = ws?.publicKey;
    final connected = ws?.isConnected == true;
    if (!_jupiterReady) return;
    final escaped = pubKey != null
        ? pubKey.replaceAll(r'\', r'\\').replaceAll("'", r"\'")
        : null;
    if (escaped != null && connected) {
      _controller.runJavaScript("window.__setPassthroughWallet('$escaped');");
      _controller.runJavaScript(
        "window.solana = { publicKey: { toBase58: function() { return '$escaped'; } }, isConnected: true };",
      );
    } else {
      _controller.runJavaScript("window.__setPassthroughWallet(null);");
      _controller.runJavaScript(
        "window.solana = { publicKey: null, isConnected: false };",
      );
    }
  }

  void _onBridgeMessage(String message) {
    try {
      final map = jsonDecode(message) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type == 'jupiterReady') {
        if (mounted) {
          setState(() => _jupiterReady = true);
          _syncWalletToJupiter();
        }
        return;
      }
      if (type == 'requestConnect') {
        // Don't open wallet from here — leaving WebView causes black screen on return.
        // Ask user to connect in the header; then we sync passthrough.
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connect your wallet using the Connect button in the header above.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        _syncWalletToJupiter(); // in case they already connected in header
        return;
      }
      if (type == 'sign') {
        final id = map['id'] as String?;
        final payload = map['payload'] as String?;
        if (id == null || payload == null) return;
        _handleSignRequest(id, payload);
      }
    } catch (_) {}
  }

  Future<void> _handleSignRequest(String id, String payloadBase64) async {
    final ws = widget.walletState;
    if (ws == null || !ws.isConnected) {
      _controller.runJavaScript(
        "window.__onSignResult('$id', '', 'Wallet not connected');",
      );
      return;
    }
    try {
      final bytes = base64Decode(payloadBase64);
      final signed = await ws.signTransactions([bytes]);
      if (signed.isEmpty) {
        _controller.runJavaScript(
          "window.__onSignResult('$id', '', 'Sign rejected');",
        );
        return;
      }
      final signedB64 = base64Encode(signed.first);
      final escaped = signedB64.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      await _controller.runJavaScript(
        "window.__onSignResult('$id', '$escaped', null);",
      );
    } catch (e) {
      final err = e.toString().replaceAll(r'\', r'\\').replaceAll("'", r"\'");
      await _controller.runJavaScript(
        "window.__onSignResult('$id', '', '$err');",
      );
    }
  }

  @override
  void initState() {
    super.initState();
    widget.walletState?.addListener(_walletListener);
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (defaultTargetPlatform == TargetPlatform.android) {
      params = AndroidWebViewControllerCreationParams
          .fromPlatformWebViewControllerCreationParams(params);
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0d0d0d))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (m) => _onBridgeMessage(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (kDebugMode) debugPrint('[JupiterWebView] onPageStarted: $url');
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (kDebugMode) debugPrint('[JupiterWebView] onPageFinished: $url');
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (kDebugMode) debugPrint('[JupiterWebView] onWebResourceError: ${e.errorCode}');
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(
        _buildHtml(),
        baseUrl: 'https://plugin.jup.ag/',
      );
  }

  @override
  void dispose() {
    widget.walletState?.removeListener(_walletListener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant JupiterWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletState != widget.walletState) {
      oldWidget.walletState?.removeListener(_walletListener);
      widget.walletState?.addListener(_walletListener);
    }
    _syncWalletToJupiter();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _loading = true);
    _jupiterReady = false;
    _controller.loadHtmlString(
      _buildHtml(),
      baseUrl: 'https://plugin.jup.ag/',
    );
  }

  Widget _buildWebViewWidget() {
    if (defaultTargetPlatform == TargetPlatform.android &&
        WebViewPlatform.instance is AndroidWebViewPlatform) {
      PlatformWebViewWidgetCreationParams params =
          PlatformWebViewWidgetCreationParams(
        controller: _controller.platform,
        layoutDirection: TextDirection.ltr,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
      params = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        params,
        displayWithHybridComposition: true,
      );
      return WebViewWidget.fromPlatformCreationParams(params: params);
    }
    return WebViewWidget(controller: _controller);
  }

  /// URL for "Open in browser" — includes referral so you earn from swaps there too.
  Uri get _jupiterExternalUrl => Uri.parse(
        'https://jup.ag/swap'
        '?inputMint=$_solMint'
        '&outputMint=$_usdcMint'
        '&referral=$_referralAccount',
      );

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(_jupiterExternalUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey<int>(widget.recreateKey),
      height: widget.height,
      child: Stack(
        children: [
          Container(
            color: const Color(0xFF0d0d0d),
            child: _buildWebViewWidget(),
          ),
          if (_loading)
            Container(
              height: widget.height,
              color: Colors.black26,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white70),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _loading ? null : _reload,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 18, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Reload',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _openInBrowser,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_browser, size: 18, color: Colors.white70),
                          SizedBox(width: 4),
                          Text(
                            'Open in browser',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
