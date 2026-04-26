import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';

class FindLinkPage extends StatefulWidget {
  final String title;
  final String url;

  const FindLinkPage({super.key, required this.title, required this.url});

  @override
  State<FindLinkPage> createState() => _FindLinkPageState();
}

class _FindLinkPageState extends State<FindLinkPage> {
  late final WebViewController _controller;
  bool _loading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    
    final uri = _normalizeUri(widget.url);
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) setState(() => _progress = progress / 100.0);
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
      
    if (uri != null) {
      _controller.loadRequest(uri);
    }
  }

  Uri? _normalizeUri(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final parsed = Uri.tryParse(input);
    if (parsed == null) return null;

    if (parsed.isAbsolute) return parsed;

    final base = Uri.tryParse(AppConfig.baseUrl);
    if (base != null && base.host.isNotEmpty) {
      final origin = Uri(
        scheme: base.scheme.isNotEmpty ? base.scheme : 'https',
        host: base.host,
        port: base.hasPort ? base.port : null,
      );
      return origin.resolveUri(parsed);
    }

    if (input.startsWith('//')) {
      return Uri.tryParse('https:$input');
    }

    if (!input.contains('://')) {
      return Uri.tryParse('https://$input');
    }

    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading || _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.transparent,
              color: Theme.of(context).primaryColor,
            ),
        ],
      ),
    );
  }
}