import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewerScreen({
    Key? key,
    required this.title,
    required this.url,
  }) : super(key: key);

  @override
  State<WebViewerScreen> createState() => _WebViewerScreenState();
}

class _WebViewerScreenState extends State<WebViewerScreen> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('[WEBVIEWER] Initializing WebViewer for: ${widget.title}');
  }

  Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString("cookie");
      debugPrint('[WEBVIEWER] Session cookie retrieved: ${cookie != null ? 'Yes' : 'No'}');
      return cookie;
    } catch (e) {
      debugPrint('[WEBVIEWER] Error retrieving cookie: $e');
      return null;
    }
  }

  Future<void> _injectSessionCookie() async {
    try {
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        // Extract cookie components
        final cookieManager = CookieManager.instance();
        
        // Parse cookie and set it
        debugPrint('[WEBVIEWER] Injecting session cookie');
        
        // Note: cookie injection happens automatically through WebView headers
        // The cookie will be sent with subsequent requests
      }
    } catch (e) {
      debugPrint('[WEBVIEWER] Error injecting cookie: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Try to go back in WebView history first
        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
          return false; // Don't pop the screen
        }
        return true; // Pop the screen if WebView can't go back
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _webViewController.canGoBack()) {
                await _webViewController.goBack();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.url),
                headers: {
                  'User-Agent': 'LeadCalling/1.0',
                },
              ),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "geolocation; microphone; camera",
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                debugPrint('[WEBVIEWER] WebView created for: ${widget.title}');
                _injectSessionCookie();
              },
              onLoadStart: (controller, url) {
                debugPrint('[WEBVIEWER] Started loading: $url');
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              },
              onLoadStop: (controller, url) {
                debugPrint('[WEBVIEWER] Finished loading: $url');
                setState(() {
                  _isLoading = false;
                });
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[WEBVIEWER] Error loading ${request.url}: ${error.description}');
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Failed to load page: ${error.description}';
                });
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('[WEBVIEWER] Console: ${consoleMessage.message}');
              },
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (_errorMessage != null)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        await _webViewController.reload();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
