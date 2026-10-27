import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/referral_attribution.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _referralCode;

  static const _allowedHost = '2s-pay.2s-group.com';

  bool _isAllowedHost(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == _allowedHost || host.endsWith('.$_allowedHost');
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final code = await ReferralAttribution.resolveReferralCode();
    if (!mounted) return;
    setState(() => _referralCode = code);
    _initializeWebView(code);
  }

  void _initializeWebView(String? referralCode) {
    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    if (controller.platform is WebKitWebViewController) {
      (controller.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);

      (controller.platform as AndroidWebViewController)
          .setOnShowFileSelector((params) async {
        final FilePickerResult? result =
            await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.any,
        );

        if (result != null && result.files.isNotEmpty) {
          return result.files
              .where((file) => file.path != null)
              .map((file) => Uri.file(file.path!).toString())
              .toList();
        }
        return <String>[];
      });
    }

    final entryUrl = ReferralAttribution.webEntryUrl(referralCode);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            if (url.startsWith("tel:") ||
                url.startsWith("sms:") ||
                url.startsWith("mailto:") ||
                url.startsWith("whatsapp:") ||
                url.contains("api.whatsapp.com") ||
                url.contains("m.me/")) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            if (!request.isMainFrame) {
              controller.loadRequest(Uri.parse(url));
              return NavigationDecision.prevent;
            }

            if (!_isAllowedHost(url)) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? false) {
              if (mounted) setState(() => _hasError = true);
            }
          },
          onPageFinished: (_) async {
            if (_referralCode != null && _referralCode!.isNotEmpty) {
              try {
                await controller.runJavaScript(
                  ReferralAttribution.injectReferralJs(_referralCode!),
                );
              } catch (_) {}
            }
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(entryUrl));

    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              if (controller != null)
                WebViewWidget(controller: controller)
              else
                const Center(child: CircularProgressIndicator()),
              if (_hasError && controller != null)
                _buildOfflineView(controller),
              if ((_isLoading && !_hasError) || controller == null)
                const LinearProgressIndicator(
                  minHeight: 2,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineView(WebViewController controller) {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Color(0xFF03469d),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connexion impossible',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vérifiez votre connexion internet puis réessayez.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              setState(() => _hasError = false);
              final current = await controller.currentUrl();
              if (current != null && _isAllowedHost(current)) {
                await controller.reload();
              } else {
                await controller.loadRequest(Uri.parse(
                  ReferralAttribution.webEntryUrl(_referralCode),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF03469d),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
