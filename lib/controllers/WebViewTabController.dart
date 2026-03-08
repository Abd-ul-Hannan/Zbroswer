import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zbrowser/controllers/DownloadController.dart';
import 'package:zbrowser/screens/DownloaderScreen.dart';
import 'package:zbrowser/database/HistoryDatabase.dart';
import 'package:zbrowser/controllers/History Controller.dart';
import 'package:zbrowser/utils/javascript_console_result.dart';
import 'package:zbrowser/dialogs+action/long_press_alert_dialog.dart';
import 'package:zbrowser/main.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/database/state_manager.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:zbrowser/screens/webview_tab.dart';

class WebViewTabController extends GetxController with WidgetsBindingObserver {
  final WebViewModel webViewModel;

  WebViewTabController({required this.webViewModel});

  InAppWebViewController? _webViewController;
  PullToRefreshController? _pullToRefreshController;
  FindInteractionController? _findInteractionController;

  final RxBool _pullToRefreshControllerDisposed = false.obs;
  final FocusNode _focusNode = FocusNode();

  final TextEditingController _httpAuthUsernameController = TextEditingController();
  final TextEditingController _httpAuthPasswordController = TextEditingController();

  // Use late initialization to ensure controllers are available
  late final BrowserModel browserModel;
  late final WindowModel windowModel;
  late final DownloadController downloadController;

  @override
  void onInit() {
    super.onInit();
    
    try {
      browserModel = Get.find<BrowserModel>();
      windowModel = Get.find<WindowModel>();
      downloadController = Get.find<DownloadController>();
    } catch (e) {
      debugPrint('Error finding controllers: $e');
      rethrow;
    }

    WidgetsBinding.instance.addObserver(this);

    if (Util.isIOS() || Util.isAndroid()) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: Colors.blue),
        onRefresh: _onPullToRefresh,
      );
    }

    if (Util.isIOS() || Util.isAndroid() || Util.isMacOS()) {
      _findInteractionController = FindInteractionController();
    }
  }

  @override
  void onClose() {
    // Dispose controllers in reverse order
    WidgetsBinding.instance.removeObserver(this);

    _pullToRefreshController?.dispose();
    _pullToRefreshControllerDisposed.value = true;
    
    _findInteractionController?.dispose();
    _focusNode.dispose();
    _httpAuthUsernameController.dispose();
    _httpAuthPasswordController.dispose();

    // Clear references
    _webViewController = null;
    webViewModel.webViewController = null;
    webViewModel.pullToRefreshController = null;
    webViewModel.findInteractionController = null;

    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_webViewController != null && (Util.isAndroid() || Util.isWindows())) {
      if (state == AppLifecycleState.paused) {
        pauseAll();
      } else if (state == AppLifecycleState.resumed) {
        resumeAll();
      }
    }
  }

  void pauseAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
    pauseTimers();
  }

  void resumeAll() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
    resumeTimers();
  }

  void pause() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.pause();
    }
  }

  void resume() {
    if (Util.isAndroid() || Util.isWindows()) {
      _webViewController?.resume();
    }
  }

  void pauseTimers() {
    if (!Util.isWindows()) {
      _webViewController?.pauseTimers();
    }
  }

  void resumeTimers() {
    if (!Util.isWindows()) {
      _webViewController?.resumeTimers();
    }
  }

  void reload() => _webViewController?.reload();

  Widget buildWebView() {
    final settings = browserModel.getSettings();

    if (Util.isAndroid()) {
      InAppWebViewController.setWebContentsDebuggingEnabled(settings.debuggingEnabled);
    }

    final initialSettings = _configureWebViewSettings(settings);

    return InAppWebView(
      keepAlive: webViewModel.keepAlive,
      webViewEnvironment: webViewEnvironment,
      initialUrlRequest: webViewModel.url != null 
          ? URLRequest(url: webViewModel.url) 
          : null,
      initialSettings: initialSettings,
      windowId: webViewModel.windowId,
      pullToRefreshController: _pullToRefreshController,
      findInteractionController: _findInteractionController,
      onWebViewCreated: _onWebViewCreated,
      onLoadStart: _onLoadStart,
      onLoadStop: _onLoadStop,
      onProgressChanged: _onProgressChanged,
      onUpdateVisitedHistory: _onUpdateVisitedHistory,
      onLongPressHitTestResult: _onLongPressHitTestResult,
      onConsoleMessage: _onConsoleMessage,
      onLoadResource: _onLoadResource,
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      onDownloadStartRequest: _onDownloadStartRequest,
      onReceivedError: _onReceivedError,
      onTitleChanged: _onTitleChanged,
      onCreateWindow: _onCreateWindow,
      onCloseWindow: _onCloseWindow,
      onPermissionRequest: _onPermissionRequest,
      onReceivedHttpAuthRequest: _onReceivedHttpAuthRequest,
    );
  }

  InAppWebViewSettings _configureWebViewSettings(dynamic settings) {
    final initialSettings = webViewModel.settings!;
    
    initialSettings.isInspectable = settings.debuggingEnabled;
    initialSettings.useOnDownloadStart = true;
    initialSettings.useOnLoadResource = true;
    initialSettings.useShouldOverrideUrlLoading = true;
    initialSettings.javaScriptCanOpenWindowsAutomatically = true;
    initialSettings.transparentBackground = true;
    initialSettings.safeBrowsingEnabled = true;
    initialSettings.disableDefaultErrorPage = true;
    initialSettings.supportMultipleWindows = true;
    initialSettings.verticalScrollbarThumbColor = const Color.fromRGBO(0, 0, 0, 0.5);
    initialSettings.horizontalScrollbarThumbColor = const Color.fromRGBO(0, 0, 0, 0.5);
    initialSettings.allowsLinkPreview = false;
    initialSettings.isFraudulentWebsiteWarningEnabled = true;
    initialSettings.disableLongPressContextMenuOnLinks = true;
    initialSettings.allowingReadAccessTo = WebUri('file://$WEB_ARCHIVE_DIR/');
    
    // PERFORMANCE: Enable caching
    initialSettings.cacheEnabled = true;
    initialSettings.cacheMode = CacheMode.LOAD_CACHE_ELSE_NETWORK;
    initialSettings.databaseEnabled = false;
    initialSettings.domStorageEnabled = true;
    initialSettings.mediaPlaybackRequiresUserGesture = false;

    if (Util.isIOS() || Util.isAndroid()) {
      initialSettings.userAgent =
          "Mozilla/5.0 (Linux; Android 9; LG-H870 Build/PKQ1.190522.001) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/83.0.4103.106 Mobile Safari/537.36";
    }

    return initialSettings;
  }

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    debugPrint('WebView created for URL: ${webViewModel.url}');
    
    _webViewController = controller;
    webViewModel.webViewController = controller;
    webViewModel.pullToRefreshController = _pullToRefreshController;
    webViewModel.findInteractionController = _findInteractionController;

    // Set settings
    final initialSettings = webViewModel.settings!;
    initialSettings.transparentBackground = false;
    await controller.setSettings(settings: initialSettings);

    if (Util.isAndroid()) {
      await controller.startSafeBrowsing();
    }

    webViewModel.settings = await controller.getSettings();

    // Update current tab state
    if (_isCurrentTab()) {
      windowModel.update();
    }
    
    debugPrint('WebView controller setup completed');
  }

  Future<void> _onLoadStart(InAppWebViewController controller, WebUri? url) async {
    if (url == null) return;

    debugPrint('Load started for URL: $url');
    
    webViewModel.isSecure = Util.urlIsSecure(url);
    webViewModel.url = url;
    webViewModel.loaded = false;
    webViewModel.setLoadedResources([]);
    webViewModel.setJavaScriptConsoleResults([]);

    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
  if (!_pullToRefreshControllerDisposed.value) _pullToRefreshController?.endRefreshing();

  webViewModel.url = url;
  webViewModel.loaded = true;

  final sslCertificate = await controller.getCertificate();
  if (sslCertificate == null && url != null && !Util.isLocalizedContent(url)) {
    webViewModel.isSecure = false;
  }

  webViewModel.title = await controller.getTitle();

  if (url != null) {
    await Future.delayed(const Duration(milliseconds: 300));
    await _updateFavicon(controller);
  }

  if (_isCurrentTab()) {
    webViewModel.needsToCompleteInitialLoad = false;
    windowModel.update();
    
    // EXTREME: Defer screenshot & save
    Future.microtask(() {
      _takeScreenshot(controller);
      StateManager.saveState(Get.currentRoute, url?.toString(), tabIndex: webViewModel.tabIndex);
      windowModel.flushInfo();
    });
  }
}


  Future<void> _updateFavicon(InAppWebViewController controller) async {
    try {
      final favicons = await controller.getFavicons();
      if (favicons != null && favicons.isNotEmpty) {
        webViewModel.favicon = favicons.reduce((a, b) => 
          (b.width ?? 0) > (a.width ?? 0) ? b : a);
        debugPrint('Favicon captured: ${webViewModel.favicon?.url}');
      } else {
        final url = webViewModel.url;
        if (url != null) {
          webViewModel.favicon = Favicon(url: WebUri('${url.origin}/favicon.ico'));
          debugPrint('Using default favicon: ${webViewModel.favicon?.url}');
        }
      }
      await _saveToHistory();
    } catch (e) {
      debugPrint('Error getting favicons: $e');
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final url = webViewModel.url;
      final title = webViewModel.title;
      final favicon = webViewModel.favicon;
      
      if (url != null && url.scheme.startsWith('http')) {
        await HistoryDatabase.instance.insertHistory({
          'title': title ?? 'No Title',
          'url': url.toString(),
          'favicon': favicon?.url?.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('Saved to history: ${url.toString()}');
        
        // Notify history controller to refresh if it exists
        try {
          if (Get.isRegistered<HistoryController>()) {
            Get.find<HistoryController>().refreshHistory();
          }
        } catch (e) {
          debugPrint('History controller not available: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }

  Future<void> _takeScreenshot(InAppWebViewController controller) async {
    try {
      final screenshotData = await controller.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 20,
        ),
      ).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );
      
      if (screenshotData != null) {
        webViewModel.screenshot = screenshotData;
        debugPrint('Screenshot captured successfully');
      }
    } catch (e) {
      debugPrint('Error taking screenshot: $e');
    }
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (progress == 100 && !_pullToRefreshControllerDisposed.value) {
      _pullToRefreshController?.endRefreshing();
    }

    webViewModel.progress = progress / 100;

    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  Future<void> _onUpdateVisitedHistory(
  InAppWebViewController controller,
  WebUri? url,
  bool? androidIsReload,
) async {
  webViewModel.url = url;
  webViewModel.title = await controller.getTitle();
  await _updateFavicon(controller);

  if (_isCurrentTab()) {
    windowModel.update();
    Future.microtask(() {
      StateManager.saveState(Get.currentRoute, url?.toString(), tabIndex: webViewModel.tabIndex);
      windowModel.flushInfo();
    });
  }
}

  Future<void> _onLongPressHitTestResult(
    InAppWebViewController controller,
    InAppWebViewHitTestResult hitTestResult,
  ) async {
    if (!LongPressAlertDialog.hitTestResultSupported.contains(hitTestResult.type)) {
      return;
    }

    final requestFocusNodeHrefResult = await controller.requestFocusNodeHref();
    if (requestFocusNodeHrefResult == null) return;

    final context = Get.context;
    if (context == null || !context.mounted) return;

    // Guard against double registration
    if (!Get.isRegistered<LongPressController>()) {
      Get.put(LongPressController());
    }

    Get.dialog(
      LongPressAlertDialog(
        webViewModel: webViewModel,
        hitTestResult: hitTestResult,
        requestFocusNodeHrefResult: requestFocusNodeHrefResult,
      ),
    ).then((_) {
      // Clean up controller after dialog closes
      if (Get.isRegistered<LongPressController>()) {
        Get.delete<LongPressController>();
      }
    });
  }

  void _onConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    final consoleResult = _createConsoleResult(consoleMessage);
    webViewModel.addJavaScriptConsoleResults(consoleResult);

    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  JavaScriptConsoleResult _createConsoleResult(ConsoleMessage consoleMessage) {
    Color consoleTextColor = Colors.black;
    Color consoleBackgroundColor = Colors.transparent;
    IconData? consoleIconData;
    Color? consoleIconColor;

    switch (consoleMessage.messageLevel) {
      case ConsoleMessageLevel.ERROR:
        consoleTextColor = Colors.red;
        consoleIconData = Icons.report_problem;
        consoleIconColor = Colors.red;
        break;
      case ConsoleMessageLevel.TIP:
        consoleTextColor = Colors.blue;
        consoleIconData = Icons.info;
        consoleIconColor = Colors.blueAccent;
        break;
      case ConsoleMessageLevel.WARNING:
        consoleBackgroundColor = const Color.fromRGBO(255, 251, 227, 1);
        consoleIconData = Icons.report_problem;
        consoleIconColor = Colors.orangeAccent;
        break;
      default:
        break;
    }

    return JavaScriptConsoleResult(
      data: consoleMessage.message,
      textColor: consoleTextColor,
      backgroundColor: consoleBackgroundColor,
      iconData: consoleIconData,
      iconColor: consoleIconColor,
    );
  }

  void _onLoadResource(InAppWebViewController controller, LoadedResource resource) {
    webViewModel.addLoadedResources(resource);
    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url;
    if (url == null) return NavigationActionPolicy.ALLOW;

    final urlStr = url.toString();

    // Block Google Lens
    if (url.scheme == 'googlelens' ||
        url.host == 'lens.google.com' ||
        urlStr.contains('google.com/lens') ||
        urlStr.contains('google.com/searchbyimage') ||
        urlStr.contains('&tbm=isch&tbs=sbi:')) {
      return NavigationActionPolicy.CANCEL;
    }

    // Handle external schemes
    const allowedSchemes = ['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about'];
    if (!allowedSchemes.contains(url.scheme)) {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return NavigationActionPolicy.CANCEL;
      }
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _onDownloadStartRequest(
    InAppWebViewController controller,
    DownloadStartRequest downloadStartRequest,
  ) async {
    try {
      final urlStr = downloadStartRequest.url.toString();
      var fileName = downloadStartRequest.suggestedFilename ?? urlStr.split('/').last;
      
      if (!fileName.contains('.')) {
        fileName = '$fileName.unknown';
      }

      await downloadController.enqueueDownloadWithQualitySelection(urlStr, fileName);
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  Future<void> _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) async {
    if (!(request.isForMainFrame ?? false)) return;

    if (!_pullToRefreshControllerDisposed.value) {
      _pullToRefreshController?.endRefreshing();
    }

    final errorUrl = request.url;
    await _webViewController?.loadData(
      data: await _generateErrorPage(errorUrl, error),
      baseUrl: errorUrl,
      historyUrl: errorUrl,
    );

    webViewModel.url = errorUrl;
    webViewModel.isSecure = false;

    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  Future<String> _generateErrorPage(WebUri? errorUrl, WebResourceError error) async {
    final css = await InAppWebViewController.tRexRunnerCss;
    final html = await InAppWebViewController.tRexRunnerHtml;

    return """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width">
  <style>$css</style>
  <style>
    .interstitial-wrapper {
      max-width: 600px;
      margin: 0 auto;
      font-size: 1em;
    }
  </style>
</head>
<body>
  $html
  <div class="interstitial-wrapper">
    <h1>Website not available</h1>
    <p>Could not load <strong>$errorUrl</strong></p>
    <p>${error.description}</p>
  </div>
</body>
</html>
""";
  }

  Future<void> _onTitleChanged(InAppWebViewController controller, String? title) async {
    webViewModel.title = title;
    debugPrint('Title changed to: $title');
    
    // Update favicon when title changes (page is fully loaded)
    await _updateFavicon(controller);
    
    if (_isCurrentTab()) {
      windowModel.update();
    }
  }

  Future<bool?> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction createWindowAction,
  ) async {
    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(),
        webViewModel: WebViewModel(
          url: WebUri("about:blank"),
          windowId: createWindowAction.windowId,
        ),
      ),
    );
    return true;
  }

  void _onCloseWindow(InAppWebViewController controller) {
    if (webViewModel.tabIndex != null) {
      windowModel.closeTab(webViewModel.tabIndex!);
    }
  }

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.GRANT,
    );
  }

  Future<HttpAuthResponse?> _onReceivedHttpAuthRequest(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) async {
    final action = await _createHttpAuthDialog(challenge);
    return HttpAuthResponse(
      username: _httpAuthUsernameController.text.trim(),
      password: _httpAuthPasswordController.text,
      action: action,
      permanentPersistence: true,
    );
  }

  bool _isCurrentTab() {
    return windowModel.getCurrentTabIndex() == webViewModel.tabIndex;
  }

  Future<void> _onPullToRefresh() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final url = await _webViewController?.getUrl();
      if (url != null) {
        await _webViewController?.loadUrl(urlRequest: URLRequest(url: url));
      }
    } else {
      await _webViewController?.reload();
    }
  }

  Future<HttpAuthResponseAction> _createHttpAuthDialog(
    URLAuthenticationChallenge challenge,
  ) async {
    HttpAuthResponseAction action = HttpAuthResponseAction.CANCEL;

    final context = Get.context;
    if (context == null || !context.mounted) return action;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Login Required"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(challenge.protectionSpace.host),
            TextField(
              decoration: const InputDecoration(labelText: "Username"),
              controller: _httpAuthUsernameController,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Password"),
              controller: _httpAuthPasswordController,
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              action = HttpAuthResponseAction.PROCEED;
              Navigator.pop(context);
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );

    return action;
  }
}