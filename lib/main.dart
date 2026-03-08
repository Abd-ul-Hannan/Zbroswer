import 'dart:async';
import 'dart:io' show Directory, Platform;

import 'package:context_menus/context_menus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zbrowser/database/state_manager.dart';
import 'package:zbrowser/settings/SettingsController.dart';
import 'package:zbrowser/controllers/DownloadController.dart';
import 'package:zbrowser/screens/DownloaderScreen.dart';
import 'package:zbrowser/controllers/FavoriteController.dart';
import 'package:zbrowser/screens/FavoriteScreen.dart';
import 'package:zbrowser/screens/History%20Screen.dart';
import 'package:zbrowser/screens/WebArchiveScreen.dart';
import 'package:zbrowser/controllers/WebArchiveController.dart';
import 'package:zbrowser/app_bar/browser_app_bar.dart';
import 'package:zbrowser/app_bar/certificates_info_popup.dart';
import 'package:zbrowser/app_bar/desktop_app_bar.dart';
import 'package:zbrowser/app_bar/tab_viewer_app_bar.dart';
import 'package:zbrowser/app_bar/webview_tab_app_bar.dart';
import 'package:zbrowser/dialogs+action/long_press_alert_dialog.dart';
import 'package:zbrowser/developers/javascript_console.dart';
import 'package:zbrowser/developers/storage_manager.dart';
import 'package:zbrowser/settings/main.dart';
import 'package:zbrowser/screens/empty_tab.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/controllers/theme_controller.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:file_saver/file_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:path/path.dart' as p;

import 'controllers/History Controller.dart';
import 'controllers/SearchHistoryController.dart';
import 'screens/browser.dart';
import 'controllers/TabViewerController.dart';
import 'controllers/connectivity_controller.dart';
import 'package:zbrowser/utils/performance_utils.dart';
import 'games/snake_game.dart';
import 'games/brick_breaker_game.dart';

late final String WEB_ARCHIVE_DIR;
late final double TAB_VIEWER_BOTTOM_OFFSET_1;
late final double TAB_VIEWER_BOTTOM_OFFSET_2;
late final double TAB_VIEWER_BOTTOM_OFFSET_3;

const double TAB_VIEWER_TOP_OFFSET_1 = 0.0;
const double TAB_VIEWER_TOP_OFFSET_2 = 10.0;
const double TAB_VIEWER_TOP_OFFSET_3 = 20.0;
const double TAB_VIEWER_TOP_SCALE_TOP_OFFSET = 250.0;
const double TAB_VIEWER_TOP_SCALE_BOTTOM_OFFSET = 230.0;

WebViewEnvironment? webViewEnvironment;
Database? db;

int windowId = 0;
String? windowModelId;

void main(List<String> args) async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // PERFORMANCE: Disable all debug in release
    if (kReleaseMode) {
      // Disable debug prints
    }
    
    // PERFORMANCE: Optimize image cache
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

    if (kDebugMode) {
      PerformanceUtils.monitorFramePerformance();
    }

    if (Util.isDesktop()) {
      windowId = args.isNotEmpty ? int.tryParse(args[0]) ?? 0 : 0;
      windowModelId = args.length > 1 ? args[1] : null;
      await WindowManagerPlus.ensureInitialized(windowId);
    }

    final appDocumentsDir = await getApplicationDocumentsDirectory();

    if (Util.isDesktop()) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = p.join(appDocumentsDir.path, "databases");
    await Directory(databasesPath).create(recursive: true);

    db = await databaseFactory.openDatabase(
      p.join(databasesPath, "myDb.db"),
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE browser (id INTEGER PRIMARY KEY, json TEXT)');
          await db.execute('CREATE TABLE windows (id TEXT PRIMARY KEY, json TEXT)');
        },
      ),
    );

    if (Util.isDesktop()) {
      WindowOptions windowOptions = WindowOptions(
        center: true,
        backgroundColor: Colors.transparent,
        titleBarStyle: Util.isWindows() ? TitleBarStyle.normal : TitleBarStyle.hidden,
        minimumSize: const Size(1280, 720),
        size: const Size(1280, 720),
      );

      WindowManagerPlus.current.waitUntilReadyToShow(windowOptions, () async {
        if (!Util.isWindows()) {
          await WindowManagerPlus.current.setAsFrameless();
          await WindowManagerPlus.current.setHasShadow(true);
        }
        await WindowManagerPlus.current.show();
        await WindowManagerPlus.current.focus();
      });
    }

    WEB_ARCHIVE_DIR = (await getApplicationSupportDirectory()).path;

    TAB_VIEWER_BOTTOM_OFFSET_1 = 150.0;
    TAB_VIEWER_BOTTOM_OFFSET_2 = 160.0;
    TAB_VIEWER_BOTTOM_OFFSET_3 = 170.0;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(
        availableVersion != null,
        'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.',
      );

      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: 'flutter_browser_app'),
      );
    }

    if (Util.isMobile()) {
      await Permission.camera.request();
      await Permission.microphone.request();
    }

    // Initialize all controllers BEFORE runApp
    await _initializeControllers();

    runApp(const FlutterBrowserApp());
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

// Separate initialization function with proper error handling
Future<void> _initializeControllers() async {
  try {
    debugPrint('=== Controller initialization started ===');
    
    // CRITICAL: Initialize models WITHOUT restoring here
    // Restoration will happen in browser.dart
    Get.put(BrowserModel(), permanent: true);
    Get.put(WindowModel(id: windowModelId), permanent: true);
    Get.put(WebViewModel(), permanent: true);

    // Theme controller
    Get.put(ThemeController(), permanent: true);

    // Feature controllers
    Get.put(ConnectivityController(), permanent: true);
    Get.put(DownloadController(), permanent: true);
    Get.put(HistoryController(), permanent: true);
    Get.put(SearchHistoryController(), permanent: true);
    Get.put(FavoriteController(), permanent: true);
    Get.put(WebArchiveController(), permanent: true);
    Get.put(SettingsController(), permanent: true);

    // UI controllers
    Get.put(BrowserAppBarController(), permanent: true);
    Get.put(TabViewerAppBarController(), permanent: true);

    // Lazy controllers
    Get.lazyPut(() => EmptyTabController(), fenix: true);
    Get.lazyPut(() => WebViewTabAppBarController(), fenix: true);
    Get.lazyPut(() => JavaScriptConsoleController(), fenix: true);
    Get.lazyPut(() => StorageManagerController(), fenix: true);
    Get.lazyPut(() => CertificateInfoController(), fenix: true);
    Get.lazyPut(() => DesktopAppBarController(), fenix: true);
    Get.lazyPut(() => LongPressController(), fenix: true);
    Get.lazyPut(() => SettingsPageController(), fenix: true);

    debugPrint('=== All controllers initialized successfully ===');
  } catch (e, stack) {
    debugPrint('❌ Controller initialization error: $e\n$stack');
    rethrow;
  }
}

class FlutterBrowserApp extends StatefulWidget {
  const FlutterBrowserApp({super.key});

  @override
  State<FlutterBrowserApp> createState() => _FlutterBrowserAppState();
}

class _FlutterBrowserAppState extends State<FlutterBrowserApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      try {
        final windowModel = Get.find<WindowModel>();
        final currentTab = windowModel.getCurrentTab();
        final currentUrl = currentTab?.webViewModel.url?.toString();
        final currentTabIndex = windowModel.getCurrentTabIndex();
        
        if (currentUrl != null) {
          StateManager.saveState('/', currentUrl, tabIndex: currentTabIndex);
          windowModel.flushInfo();
          debugPrint('💾 App lifecycle save: $currentUrl at tab $currentTabIndex');
        }
      } catch (e) {
        debugPrint('Error saving on lifecycle: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (themeController) {
        final materialApp = GetMaterialApp(
          title: 'Flutter Browser',
          debugShowCheckedModeBanner: false,
          theme: ThemeController.lightTheme,
          darkTheme: ThemeController.darkTheme,
          themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          smartManagement: SmartManagement.keepFactory,
          defaultTransition: Transition.native,
          transitionDuration: const Duration(milliseconds: 200),
          enableLog: false,
          getPages: [
            GetPage(
              name: '/',
              page: () => const Browser(),
            ),
            GetPage(
              name: '/settings',
              page: () => const SettingsPage(),
            ),
            GetPage(
              name: '/downloads',
              page: () => const DownloadManagerScreen(),
            ),
            GetPage(
              name: '/favorites',
              page: () => const FavoritesScreen(),
            ),
            GetPage(
              name: '/history',
              page: () => const HistoryScreen(),
            ),
            GetPage(
              name: '/webarchives',
              page: () => const WebArchivesScreen(),
            ),
            GetPage(
              name: '/snake',
              page: () => SnakeGame(),
            ),
            GetPage(
              name: '/brickbreaker',
              page: () => const BrickBreakerGame(),
            ),
          ],
        );

        if (Util.isMobile()) {
          return materialApp;
        }

        // Desktop: Wrap with ContextMenuOverlay and Window Listener
        return DesktopWindowWrapper(child: materialApp);
      },
    );
  }
}

class DesktopWindowWrapper extends StatefulWidget {
  final Widget child;

  const DesktopWindowWrapper({super.key, required this.child});

  @override
  State<DesktopWindowWrapper> createState() => _DesktopWindowWrapperState();
}

class _DesktopWindowWrapperState extends State<DesktopWindowWrapper> with WindowListener {
  AppLifecycleListener? _appLifecycleListener;

  @override
  void initState() {
    super.initState();

    if (WindowManagerPlus.current.id > 0) {
      WindowManagerPlus.current.addListener(this);

      if (Platform.isMacOS) {
        _appLifecycleListener = AppLifecycleListener(
          onStateChange: _handleStateChange,
        );
      }
    }
  }

  void _handleStateChange(AppLifecycleState state) {
    if (WindowManagerPlus.current.id > 0 && 
        Platform.isMacOS && 
        state == AppLifecycleState.hidden) {
      SchedulerBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
    }
  }

  @override
  void dispose() {
    if (WindowManagerPlus.current.id > 0) {
      WindowManagerPlus.current.removeListener(this);
    }
    _appLifecycleListener?.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus([int? windowId]) {
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(false);
    }
  }

  @override
  void onWindowBlur([int? windowId]) {
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContextMenuOverlay(child: widget.child);
  }
}