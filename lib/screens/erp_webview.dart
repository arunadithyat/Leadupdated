import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ERPPortalScreen extends StatefulWidget {
  const ERPPortalScreen({Key? key}) : super(key: key);

  @override
  State<ERPPortalScreen> createState() => _ERPPortalScreenState();
}

class _ERPPortalScreenState extends State<ERPPortalScreen> {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  String _currentUrl = 'https://stage.homegeniegroup.in/app';

  @override
  void initState() {
    super.initState();
    _initializeUrl();
  }

  Future<void> _initializeUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final cookie = prefs.getString('cookie');

      if (!isLoggedIn || cookie == null || cookie.isEmpty) {
        debugPrint('[ERP] Not logged in, redirecting to login');
        if (mounted) {
          setState(() {
            _currentUrl = 'https://erp.homegeniegroup.in/login';
            _isLoading = true;
          });
        }
      } else {
        debugPrint('[ERP] User logged in, loading ERP Portal');
        if (mounted) {
          setState(() {
            _currentUrl = 'https://erp.homegeniegroup.in/app';
            _isLoading = true;
          });
        }
      }
    } catch (e) {
      debugPrint('[ERP] Error initializing: $e');
      if (mounted) {
        setState(() {
          _currentUrl = 'https://erp.homegeniegroup.in/login';
          _isLoading = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _webViewController.canGoBack()) {
          await _webViewController.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ERP Portal'),
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
                url: WebUri(_currentUrl),
              ),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                javaScriptEnabled: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                debugPrint('[ERP] WebView created, loading: $_currentUrl');
              },
              onLoadStart: (controller, url) {
                debugPrint('[ERP] Started loading: $url');
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                }
              },
              onLoadStop: (controller, url) {
                debugPrint('[ERP] Finished loading: $url');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[ERP] Error loading ${request.url}: ${error.description}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${error.description}'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
