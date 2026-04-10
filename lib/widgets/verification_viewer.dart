import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/iframe_helper_stub.dart'
    if (dart.library.html) '../utils/iframe_helper_web.dart';

class VerificationViewer extends StatefulWidget {
  final String url;
  final VoidCallback? onComplete;

  const VerificationViewer({
    Key? key,
    required this.url,
    this.onComplete,
  }) : super(key: key);

  @override
  State<VerificationViewer> createState() => _VerificationViewerState();
}

class _VerificationViewerState extends State<VerificationViewer> {
  WebViewController? _controller;
  final String _viewId = 'verification-iframe';
  Object? _messageListener;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Register IFrame platform view on web
      registerIframeView(_viewId, widget.url);

      // Listen for postMessage from the verification iframe
      _messageListener = addWebMessageListener(_viewId, (String data) {
        if (data.contains('verification_success') || data.contains('verification-completed')) {
          if (mounted && widget.onComplete != null) {
            widget.onComplete!();
          }
        }
      });
    } else {
      // Mobile: use WebView
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onWebResourceError: (WebResourceError error) {},
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      removeWebMessageListener(_messageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fermion Verification'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.onComplete != null)
            TextButton(
              onPressed: widget.onComplete,
              child: const Text("I'm Done", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_rounded, size: 64, color: Colors.blue),
                    const SizedBox(height: 24),
                    const Text(
                      'Ready to Verify?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To ensure maximum security and proper functionality, the verification assessment will open in a new browser tab.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => openUrlInNewTab(widget.url),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Launch Verification'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: widget.onComplete,
                      child: const Text('Already finished? Click here to refresh'),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller!),
    );
  }
}
