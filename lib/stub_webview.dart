// Stub for webview_flutter on Web
import 'package:flutter/material.dart';
class WebViewController {
  WebViewController setJavaScriptMode(dynamic mode) => this;
  WebViewController loadRequest(Uri uri) => this;
  WebViewController setNavigationDelegate(dynamic delegate) => this;
}
class WebViewWidget extends StatelessWidget {
  const WebViewWidget({super.key, required WebViewController controller});
  @override
  Widget build(BuildContext context) => const SizedBox();
}
class JavaScriptMode { static const unrestricted = JavaScriptMode._(); const JavaScriptMode._(); }
class NavigationDelegate {
  const NavigationDelegate({Function(String)? onPageFinished});
}
