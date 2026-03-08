import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart' hide Context;
import 'package:zbrowser/controllers/TabViewerController.dart';
import 'package:zbrowser/controllers/WebViewTabController.dart';
import 'package:zbrowser/controllers/connectivity_controller.dart';
import 'package:zbrowser/app_bar/browser_app_bar.dart';
import 'package:zbrowser/app_bar/tab_viewer_app_bar.dart';
import 'package:zbrowser/tools/custom_image.dart';
import 'package:zbrowser/screens/empty_tab.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/controllers/theme_controller.dart';
import 'package:zbrowser/screens/tab_viewer.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'package:zbrowser/screens/offline_screen.dart';
import 'package:zbrowser/database/state_manager.dart';

class Browser extends StatefulWidget {
  const Browser({super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isRestoringState = false;
  Timer? _saveTimer;
  Timer? _periodicSaveTimer;
  DateTime? _lastSaveTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start initialization immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeBrowser();
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _periodicSaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    // Final save on dispose
    _saveCurrentState();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('🔄 Browser lifecycle: $state');
    
    // Save on ANY backgrounding event
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive || 
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      
      _saveTimer?.cancel();
      _saveCurrentState();
      
      debugPrint('✅ State saved on $state');
    }
  }

  void _saveCurrentState() {
    // EXTREME: Throttle to 10s
    final now = DateTime.now();
    if (_lastSaveTime != null && now.difference(_lastSaveTime!).inSeconds < 10) return;
    _lastSaveTime = now;
    
    try {
      final windowModel = Get.find<WindowModel>();
      final currentTab = windowModel.getCurrentTab();
      final currentUrl = currentTab?.webViewModel.url?.toString();
      final currentRoute = Get.currentRoute;
      final currentTabIndex = windowModel.getCurrentTabIndex();
      
      StateManager.saveState(currentRoute, currentUrl, tabIndex: currentTabIndex >= 0 ? currentTabIndex : null);
      
      // Defer heavy ops
      Future.microtask(() {
        windowModel.flushInfo();
        Get.find<BrowserModel>().flush();
      });
    } catch (e) {}
  }

  Future<void> _initializeBrowser() async {
    if (_isInitialized || _isRestoringState) return;
    _isRestoringState = true;

    try {
      final browserModel = Get.find<BrowserModel>();
      final windowModel = Get.find<WindowModel>();

      // EXTREME: Parallel everything
      final results = await Future.wait([
        StateManager.restoreState(),
        browserModel.restore(),
        windowModel.restore(),
      ]);
      
      final savedState = results[0] as Map<String, dynamic>;
      final savedUrl = savedState['url'] as String?;
      final savedTabIndex = savedState['tabIndex'] as int?;
      
      browserModel.isRestored = true;
      
      // Defer ALL non-critical
      Future.microtask(() {
        Get.find<ThemeController>().loadThemeFromRestoredSettings();
        _handleIntentData();
        if (mounted) precacheImage(const AssetImage("assets/icon/icon.png"), context);
      });

      if (savedUrl != null && savedUrl.isNotEmpty) {
        if (windowModel.webViewTabs.isEmpty) {
          windowModel.addTab(WebViewTab(
            key: GlobalKey(),
            webViewModel: WebViewModel(url: WebUri(savedUrl)),
          ));
        } else {
          final targetIndex = (savedTabIndex ?? 0).clamp(0, windowModel.webViewTabs.length - 1);
          windowModel.webViewTabs[targetIndex].webViewModel.url = WebUri(savedUrl);
          windowModel.showTab(targetIndex);
        }
      } else if (windowModel.webViewTabs.isNotEmpty) {
        windowModel.showTab(windowModel.webViewTabs.length - 1);
      }

      _isInitialized = true;
      _isRestoringState = false;
      if (mounted) setState(() {});
      
      // EXTREME: 120s auto-save
      _periodicSaveTimer = Timer.periodic(const Duration(seconds: 120), (_) => _saveCurrentState());
    } catch (e) {
      _isRestoringState = false;
    }
  }

  Future<void> _handleIntentData() async {
    if (Util.isAndroid()) {
      const platform = MethodChannel('com.pichillilorenzo.flutter_browser.intent_data');
      try {
        final String? url = await platform.invokeMethod("getIntentData");
        if (url != null && url.isNotEmpty) {
          final windowModel = Get.find<WindowModel>();
          windowModel.addTab(
            WebViewTab(
              key: GlobalKey(),
              webViewModel: WebViewModel(url: WebUri(url)),
            ),
          );
        }
      } catch (e) {
        debugPrint("Intent error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final connectivityController = Get.find<ConnectivityController>();
      
      // Show offline screen when no internet connection
      if (!connectivityController.isConnected.value) {
        return const OfflineScreen();
      }

      final browserModel = Get.find<BrowserModel>();
      final windowModel = Get.find<WindowModel>();
      
      final canShowTabScroller = 
          browserModel.showTabScroller.value && windowModel.webViewTabs.isNotEmpty;

      return IndexedStack(
        index: canShowTabScroller ? 1 : 0,
        children: [
          _buildWebViewTabs(),
          if (canShowTabScroller) _buildWebViewTabsViewer(),
        ],
      );
    });
  }

  Widget _buildWebViewTabs() {
    return WillPopScope(
      onWillPop: () async {
        final windowModel = Get.find<WindowModel>();
        final currentTab = windowModel.getCurrentTab();
        final controller = currentTab?.webViewModel.webViewController;

        if (controller != null && await controller.canGoBack()) {
          controller.goBack();
          return false;
        }

        if (currentTab != null && currentTab.webViewModel.tabIndex != null) {
          windowModel.closeTab(currentTab.webViewModel.tabIndex!);
          return false;
        }

        return windowModel.webViewTabs.isEmpty;
      },
      child: Listener(
        onPointerUp: (_) {
          if (Util.isIOS() || Util.isAndroid()) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: Scaffold(
          appBar: const BrowserAppBar(),
          body: Obx(() {
            final windowModel = Get.find<WindowModel>();
            
            if (windowModel.webViewTabs.isEmpty) {
              return const EmptyTab();
            }

            final currentTab = windowModel.getCurrentTab();
            if (currentTab == null) {
              return const EmptyTab();
            }

            return Stack(
              children: [
                IndexedStack(
                  index: windowModel.getCurrentTabIndex().clamp(0, windowModel.webViewTabs.length - 1),
                  children: windowModel.webViewTabs,
                ),
                Obx(() {
                  final webViewModel = windowModel.getCurrentTab()?.webViewModel;
                  final progress = webViewModel?.progress ?? 1.0;
                  
                  if (progress >= 1.0) return const SizedBox.shrink();

                  return Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4.0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildWebViewTabsViewer() {
    return WillPopScope(
      onWillPop: () async {
        final browserModel = Get.find<BrowserModel>();
        browserModel.showTabScroller.value = false;
        
        if (Get.isRegistered<TabViewerController>()) {
          try {
            final controller = Get.find<TabViewerController>();
            controller.onClose();
            await Get.delete<TabViewerController>();
          } catch (e) {
            debugPrint('Error cleaning up TabViewerController: $e');
          }
        }
        return false;
      },
      child: Scaffold(
        appBar: const TabViewerAppBar(),
        body: Obx(() {
          final windowModel = Get.find<WindowModel>();
          final currentTabIndex = windowModel.getCurrentTabIndex();
          
          return LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final screenWidth = constraints.maxWidth;

              return TabViewer(
                key: ValueKey('tab_viewer_${windowModel.webViewTabs.length}_$currentTabIndex'),
                useGridLayout: false,
                children: windowModel.webViewTabs.map((webViewTab) {
                  return _buildTabViewerItem(webViewTab, screenHeight, screenWidth);
                }).toList(),
                onTabSelected: (index) {
                  final browserModel = Get.find<BrowserModel>();
                  browserModel.showTabScroller.value = false;
                  
                  if (Get.isRegistered<TabViewerController>()) {
                    try {
                      final controller = Get.find<TabViewerController>();
                      controller.onClose();
                      Get.delete<TabViewerController>();
                    } catch (e) {
                      debugPrint('Error cleaning up: $e');
                    }
                  }
                  
                  windowModel.showTab(index);
                },
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildTabViewerItem(WebViewTab webViewTab, double screenHeight, double screenWidth) {
    final windowModel = Get.find<WindowModel>();
    final screenshotData = webViewTab.webViewModel.screenshot;
    final url = webViewTab.webViewModel.url;
    
    final faviconUrl = webViewTab.webViewModel.favicon?.url ??
        (url != null && ["http", "https"].contains(url.scheme)
            ? Uri.parse("${url.origin}/favicon.ico")
            : null);

    final isCurrentTab = windowModel.getCurrentTabIndex() == webViewTab.webViewModel.tabIndex;

    return Container(
      height: screenHeight * 0.7,
      width: screenWidth,
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.8,
        maxWidth: screenWidth,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabViewerHeader(webViewTab, faviconUrl, url, isCurrentTab, screenWidth),
          Expanded(
            child: _buildTabViewerScreenshot(screenshotData, screenHeight, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildTabViewerHeader(
    WebViewTab webViewTab,
    Uri? faviconUrl,
    WebUri? url,
    bool isCurrentTab,
    double screenWidth,
  ) {
    return Material(
      color: isCurrentTab
          ? Colors.blue
          : (webViewTab.webViewModel.isIncognitoMode ? Colors.black : Colors.white),
      child: Container(
        constraints: BoxConstraints(maxWidth: screenWidth, maxHeight: 80),
        child: ListTile(
          leading: CustomImage(url: faviconUrl, maxWidth: 30.0, height: 30.0),
          title: Text(
            webViewTab.webViewModel.title ?? url?.toString() ?? "",
            maxLines: 1,
            style: TextStyle(
              color: webViewTab.webViewModel.isIncognitoMode || isCurrentTab
                  ? Colors.white
                  : Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            url?.toString() ?? "",
            style: TextStyle(
              color: webViewTab.webViewModel.isIncognitoMode || isCurrentTab
                  ? Colors.white60
                  : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.close,
              size: 20.0,
              color: webViewTab.webViewModel.isIncognitoMode || isCurrentTab
                  ? Colors.white60
                  : Colors.black54,
            ),
            onPressed: () => _closeTab(webViewTab),
          ),
        ),
      ),
    );
  }

  Widget _buildTabViewerScreenshot(Uint8List? screenshotData, double screenHeight, double screenWidth) {
    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.6, maxWidth: screenWidth),
      decoration: const BoxDecoration(color: Colors.white),
      child: screenshotData != null
          ? Image.memory(screenshotData, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.web, size: 48, color: Colors.grey));
              })
          : const Center(child: Icon(Icons.web, size: 48, color: Colors.grey)),
    );
  }

  void _closeTab(WebViewTab webViewTab) {
    final windowModel = Get.find<WindowModel>();
    final browserModel = Get.find<BrowserModel>();

    if (webViewTab.webViewModel.tabIndex != null) {
      windowModel.closeTab(webViewTab.webViewModel.tabIndex!);
      
      if (windowModel.webViewTabs.isEmpty) {
        browserModel.showTabScroller.value = false;
        
        if (Get.isRegistered<TabViewerController>()) {
          try {
            final controller = Get.find<TabViewerController>();
            controller.onClose();
            Get.delete<TabViewerController>();
          } catch (e) {
            debugPrint('Error cleaning up: $e');
          }
        }
      } else {
        if (Get.isRegistered<TabViewerController>()) {
          try {
            final controller = Get.find<TabViewerController>();
            final newIndex = windowModel.getCurrentTabIndex().clamp(0, windowModel.webViewTabs.length - 1);
            controller.initialize(windowModel.webViewTabs.length, newIndex);
          } catch (e) {
            debugPrint('Error reinitializing: $e');
          }
        }
      }
    }
  }
}
