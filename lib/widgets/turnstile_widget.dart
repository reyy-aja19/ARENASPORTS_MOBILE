import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/turnstile_config.dart';

/// CAPTCHA interaktif Cloudflare Turnstile yang dirender di WebView.
///
/// Saat konten challenge selesai, token diubah menjadi [TurnstileWidget.onToken].
class TurnstileWidget extends StatefulWidget {
  const TurnstileWidget({
    super.key,
    this.height = 96,
    this.siteKey = TurnstileConfig.siteKey,
    required this.onToken,
  });

  final double height;
  final String siteKey;
  final ValueChanged<String> onToken;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  String? _lastToken;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _startPolling()),
      )
      ..loadHtmlString(_page(widget.siteKey));
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final result = await _controller.runJavaScriptReturningResult(
        "window.__cfToken || ''",
      );
      final token = result.toString().trim();
      if (token.isEmpty || token == _lastToken) return;
      _lastToken = token;
      widget.onToken(token);
    } catch (_) {
      // Abaikan error polling (WebView belum siap atau challenge gagal).
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// HTML yang memuat challenge Turnstile dan menyimpan token di `window.__cfToken`.
String _page(String siteKey) {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body { margin: 0; padding: 0; overflow: hidden; background: transparent; }
  #cf-turnstile-widget { width: 100%; height: 72px; }
</style>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
</head>
<body>
<div id="cf-turnstile-widget"></div>
<script>
  window.__cfToken = '';
  function renderTurnstile() {
    if (!window.turnstile) { setTimeout(renderTurnstile, 200); return; }
    turnstile.render('cf-turnstile-widget', {
      sitekey: '$siteKey',
      theme: 'light',
      callback: function (token) { window.__cfToken = token; },
      'expired-callback': function () { window.__cfToken = ''; },
      'error-callback': function () { window.__cfToken = ''; }
    });
  }
  renderTurnstile();
</script>
</body>
</html>
''';
}

/// Dialog CAPTCHA Turnstile: pop otomatis dengan token setelah konten
/// berhasil divalidasi, atau `null` bila pengguna membatalkannya.
class TurnstileDialog extends StatefulWidget {
  const TurnstileDialog({super.key, required this.title});

  final String title;

  @override
  State<TurnstileDialog> createState() => _TurnstileDialogState();
}

class _TurnstileDialogState extends State<TurnstileDialog> {
  bool _popped = false;

  void _popWithToken(String token) {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 110,
        child: TurnstileWidget(
          height: 96,
          onToken: _popWithToken,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

/// Tampilkan dialog CAPTCHA Turnstile.
///
/// Return future resolvasin dengan token saat challenge selesai,
/// atau `null` saat pengguna membatalkannya.
Future<String?> showTurnstileDialog({
  required BuildContext context,
  required String title,
}) {
  return showDialog<String?>(
    context: context,
    builder: (_) => TurnstileDialog(title: title),
  );
}
