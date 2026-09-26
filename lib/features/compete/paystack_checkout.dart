import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../router/app_router.dart';
import 'registration_flow.dart';

/// Paystack redirects the user's browser to `${SITE_URL}/api/paystack/callback?reference=…` after
/// checkout. The site host differs per environment (production, a LAN dev server), so the check is
/// on the path, and never matches Paystack's own domain.
bool isPaystackCallback(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'paystack.com' || host.endsWith('.paystack.com')) return false;
  final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return path == '/api/paystack/callback';
}

class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.authorizationUrl});
  final String authorizationUrl;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          if (isPaystackCallback(Uri.parse(request.url))) {
            // Do not load it: the app polls GET /payments/{reference} instead, and the callback
            // page would only redirect to the website.
            if (!_done && mounted) {
              _done = true;
              Navigator.of(context).pop(true);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appName),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}

/// Completes `true` when checkout reached the callback URL, `false` when the user closed it first.
Future<bool> openPaystackCheckout(BuildContext context, String authorizationUrl) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaystackCheckoutScreen(authorizationUrl: authorizationUrl)),
  );
  return result ?? false;
}

/// The app's real launcher; wired in `main()` via `paystackLauncherProvider.overrideWith`. It finds
/// the navigator through the router, so no extra navigator key exists.
PaystackLauncher paystackLauncherFromRouter(Ref ref) => (url) {
      final context = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (context == null) return Future.value(false);
      return openPaystackCheckout(context, url);
    };
