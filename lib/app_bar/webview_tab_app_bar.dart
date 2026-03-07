import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_font_icons/flutter_font_icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zbrowser/routes/custom_popup_dialog_page_route.dart';

import '../screens/FavoriteScreen.dart';
import '../screens/History Screen.dart';
import '../database/HistoryDatabase.dart';
import '../controllers/SearchHistoryController.dart';
import '../screens/WebArchiveScreen.dart';
import '../tools/animated_flutter_browser_logo.dart';
import '../app_bar/url_info_popup.dart';
import '../tools/custom_image.dart';
import '../dialogs+action/custom_popup_dialog.dart';
import '../tools/custom_popup_menu_item.dart';
import '../main.dart';
import '../models/browser_model.dart';
import '../models/favorite_model.dart';
import '../models/web_archive_model.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import '../developers/main.dart';
import '../settings/main.dart';
import '../dialogs+action/popup_menu_actions.dart';
import '../tools/project_info_popup.dart';
import '../dialogs+action/tab_popup_menu_actions.dart';
import '../utils/util.dart';
import '../screens/webview_tab.dart';
import 'package:zbrowser/screens/DownloaderScreen.dart';
import '../database/state_manager.dart';

class WebViewTabAppBar extends StatelessWidget {
  final void Function()? showFindOnPage;

  const WebViewTabAppBar({super.key, this.showFindOnPage});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      WebViewTabAppBarController(showFindOnPage: showFindOnPage),
      tag: 'webview_appbar',
    );

    return Obx(() {
      final windowModel = Get.find<WindowModel>();
      final webViewModel = windowModel.getCurrentTab()?.webViewModel ?? WebViewModel();
      
      controller.updateSearchText(webViewModel.url);

      Widget? leading = controller.buildAppBarHomePageWidget();

      return AppBar(
        backgroundColor: webViewModel.isIncognitoMode
            ? Colors.black38
            : Theme.of(context).colorScheme.primaryContainer,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            if (leading != null) leading,
            Expanded(child: controller.buildSearchTextField()),
          ],
        ),
        actions: controller.buildActionsMenu(context),
      );
    });
  }
}

class WebViewTabAppBarController extends GetxController {
  final void Function()? showFindOnPage;
  
  BrowserModel get browserModel => Get.find<BrowserModel>();
  WindowModel get windowModel => Get.find<WindowModel>();
  WebViewModel? get currentWebViewModel => 
    windowModel.getCurrentTab()?.webViewModel;

  WebViewTabAppBarController({this.showFindOnPage});

  final TextEditingController searchController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final GlobalKey tabInkWellKey = GlobalKey();
  final Duration customPopupDialogTransitionDuration = 
    const Duration(milliseconds: 300);
  CustomPopupDialogPageRoute? route;
  
  SearchHistoryController? _searchHistoryController;
  SearchHistoryController get searchHistoryController => 
    _searchHistoryController ??= Get.find<SearchHistoryController>();
  
  final OutlineInputBorder outlineBorder = const OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent, width: 0.0),
    borderRadius: BorderRadius.all(Radius.circular(50.0)),
  );
  
  bool shouldSelectText = true;
  Worker? _urlWorker;

  @override
  void onInit() {
    super.onInit();
    
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        updateSearchText(currentWebViewModel?.url);
      }
    });
  }

  @override
  void onClose() {
    _urlWorker?.dispose();
    focusNode.dispose();
    searchController.dispose();
    super.onClose();
  }

  void updateSearchText(WebUri? url) {
    if (!focusNode.hasFocus) {
      final newText = url?.toString() ?? "";
      if (searchController.text != newText) {
        debugPrint('AppBar: Updating search text to: $newText');
        searchController.text = newText;
      }
    }
  }

  Widget? buildAppBarHomePageWidget() {
    final settings = browserModel.getSettings();

    if (Util.isMobile() && !settings.homePageEnabled) return null;

    final children = <Widget>[];

    if (Util.isDesktop()) {
      children.addAll([
        IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () => currentWebViewModel?.webViewController?.goBack(),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () => currentWebViewModel?.webViewController?.goForward(),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () => currentWebViewModel?.webViewController?.reload(),
        ),
      ]);
    }

    if (settings.homePageEnabled || Util.isDesktop()) {
      children.add(
        IconButton(
          icon: const Icon(Icons.home, size: 20),
          padding: EdgeInsets.zero,
          onPressed: () {
            final url = settings.homePageEnabled && 
                settings.customUrlHomePage.isNotEmpty
                ? WebUri(settings.customUrlHomePage)
                : WebUri(settings.searchEngine.url);

            if (currentWebViewModel?.webViewController != null) {
              currentWebViewModel!.webViewController!.loadUrl(
                urlRequest: URLRequest(url: url)
              );
            } else {
              addNewTab(url: url);
            }
          },
        ),
      );
    }

    if (children.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget buildSearchTextField() {
    final settings = browserModel.getSettings();

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 40.0,
        maxHeight: 40.0,
      ),
      child: Container(
        height: 40.0,
        child: Stack(
          children: [
            TextField(
              onSubmitted: (value) async {
                if (value.trim().isEmpty) return;
                await _handleSearch(value.trim());
              },
              onTap: () {
                if (!shouldSelectText || searchController.text.isEmpty) return;
                shouldSelectText = false;
                searchController.selection = TextSelection(
                  baseOffset: 0, 
                  extentOffset: searchController.text.length
                );
              },
              onTapOutside: (_) {
                shouldSelectText = true;
              },
              keyboardType: TextInputType.url,
              focusNode: focusNode,
              controller: searchController,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(
                  left: 45.0, 
                  top: 10.0, 
                  right: 10.0, 
                  bottom: 10.0
                ),
                filled: true,
                fillColor: Colors.white,
                border: outlineBorder,
                focusedBorder: outlineBorder,
                enabledBorder: outlineBorder,
                hintText: "Search for or type a web address",
                hintStyle: const TextStyle(
                  color: Colors.black54, 
                  fontSize: 16.0
                ),
              ),
              style: const TextStyle(color: Colors.black, fontSize: 16.0),
            ),
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: GetBuilder<WindowModel>(
                builder: (wm) {
                  final webViewModel = wm.getCurrentTab()?.webViewModel;
                  return Center(
                    child: IconButton(
                      icon: Icon(
                        webViewModel?.isIncognitoMode ?? false
                            ? MaterialCommunityIcons.incognito
                            : (webViewModel?.isSecure ?? false)
                                ? (webViewModel?.url?.scheme == "file" 
                                    ? Icons.offline_pin 
                                    : Icons.lock)
                                : Icons.info_outline,
                        color: (webViewModel?.isSecure ?? false) 
                            ? Colors.green 
                            : Colors.grey,
                      ),
                      onPressed: showUrlInfo,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSearch(String value) async {
    try {
      final settings = browserModel.getSettings();
      WebUri url;

      // Better URL validation and construction
      if (_isValidUrl(value)) {
        url = value.startsWith('http') 
            ? WebUri(value)
            : WebUri('https://$value');
      } else {
        // Use search engine for non-URL queries
        final searchQuery = Uri.encodeComponent(value);
        url = WebUri('${settings.searchEngine.searchUrl}$searchQuery');
        searchHistoryController.addSearch(value);
      }

      debugPrint('AppBar: Loading URL: $url');

      // Hide keyboard first
      focusNode.unfocus();
      
      final currentTab = windowModel.getCurrentTab();
      
      if (currentTab?.webViewModel.webViewController != null) {
        // Load URL in existing tab
        await currentTab!.webViewModel.webViewController!.loadUrl(
          urlRequest: URLRequest(url: url)
        );
        
        // Update the WebViewModel immediately
        currentTab.webViewModel.url = url;
        currentTab.webViewModel.loaded = false;
        currentTab.webViewModel.progress = 0.0;
        
      } else {
        // Create new tab if no controller exists
        debugPrint('AppBar: No controller found, creating new tab');
        final newWebViewModel = WebViewModel(
          url: url,
          needsToCompleteInitialLoad: false,
        );
        final newTab = WebViewTab(
          key: GlobalKey(), 
          webViewModel: newWebViewModel
        );
        windowModel.addTab(newTab);
      }
      
      // Update search text to show the URL being loaded
      updateSearchText(url);
      
    } catch (e) {
      debugPrint('Search error: $e');
      Get.snackbar(
        'Search Error',
        'Failed to load: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  bool _isValidUrl(String value) {
    // Check if it's a valid URL pattern
    final urlPattern = RegExp(
      r'^(https?:\/\/)?' // protocol
      r'((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|' // domain name
      r'((\d{1,3}\.){3}\d{1,3}))' // OR ip (v4) address
      r'(\:\d+)?(\/[-a-z\d%_.~+]*)*' // port and path
      r'(\?[;&a-z\d%_.~+=-]*)?' // query string
      r'(\#[-a-z\d_]*)?\$', // fragment locator
      caseSensitive: false,
    );
    
    return urlPattern.hasMatch(value) || 
           value.contains('.') && !value.contains(' ');
  }

  List<Widget> buildActionsMenu(BuildContext context) {
    final settings = browserModel.getSettings();
    final List<Widget> actions = [];

    if (settings.homePageEnabled) {
      actions.add(const SizedBox(width: 10.0));
    }

    if (!Util.isDesktop()) {
      actions.add(
        GetBuilder<WindowModel>(
          builder: (wm) {
            return InkWell(
              key: tabInkWellKey,
              onLongPress: () => _showTabLongPressMenu(context),
              onTap: () => _onTabCountTapped(context),
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10.0, 
                  vertical: 15.0
                ),
                decoration: BoxDecoration(
                  border: Border.all(width: 2.0),
                  borderRadius: BorderRadius.circular(5.0),
                ),
                constraints: const BoxConstraints(minWidth: 25.0),
                child: Center(
                  child: Text(
                    "${wm.webViewTabs.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 14.0
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    actions.add(const SizedBox(width: 5));

    actions.add(
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        position: PopupMenuPosition.under,
        onSelected: handlePopupChoice,
        itemBuilder: (_) => _buildPopupMenuItems(context),
      ),
    );

    return actions;
  }

  void _showTabLongPressMenu(BuildContext context) async {
    final RenderBox? box = tabInkWellKey.currentContext?.findRenderObject() 
      as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero);

    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, 
        position.dy + box.size.height, 
        box.size.width, 
        0
      ),
      items: TabPopupMenuActions.choices.map((action) {
        IconData? icon;
        switch (action) {
          case TabPopupMenuActions.CLOSE_TABS:
            icon = Icons.cancel;
            break;
          case TabPopupMenuActions.NEW_TAB:
            icon = Icons.add;
            break;
          case TabPopupMenuActions.NEW_INCOGNITO_TAB:
            icon = MaterialCommunityIcons.incognito;
            break;
        }
        return PopupMenuItem(
          value: action, 
          child: Row(
            children: [
              Icon(icon), 
              const SizedBox(width: 10), 
              Text(action)
            ]
          )
        );
      }).toList(),
    );

    if (choice != null) {
      switch (choice) {
        case TabPopupMenuActions.CLOSE_TABS:
          windowModel.closeAllTabs();
          break;
        case TabPopupMenuActions.NEW_TAB:
          addNewTab();
          break;
        case TabPopupMenuActions.NEW_INCOGNITO_TAB:
          addNewIncognitoTab();
          break;
      }
    }
  }

  Future<void> _onTabCountTapped(BuildContext context) async {
    if (windowModel.webViewTabs.isEmpty) return;

    final webViewModel = windowModel.getCurrentTab()?.webViewModel;
    final webViewController = webViewModel?.webViewController;

    // Hide keyboard
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    focusNode.unfocus();
    
    if (webViewController != null) {
      await webViewController.evaluateJavascript(
        source: "document.activeElement.blur();"
      );
    }
    
    await Future.delayed(const Duration(milliseconds: 300));

    // Take screenshot for preview
    if (webViewModel != null && webViewController != null) {
      webViewModel.screenshot = await webViewController.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG, 
          quality: 20
        ),
      ).timeout(
        const Duration(milliseconds: 1500), 
        onTimeout: () => null
      );
    }

    browserModel.showTabScroller.value = true;
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems(BuildContext context) {
    final List<PopupMenuEntry<String>> items = [];

    items.add(
      CustomPopupMenuItem<String>(
        enabled: true,
        isIconButtonRow: true,
        child: GetBuilder<WindowModel>(
          builder: (windowModel) {
            final webViewModel = windowModel.getCurrentTab()?.webViewModel ?? 
              WebViewModel();
            
            final favorite = webViewModel.url != null
                ? FavoriteModel(
                    url: webViewModel.url, 
                    title: webViewModel.title ?? "", 
                    favicon: webViewModel.favicon
                  )
                : null;
            
            final isFavorite = favorite != null && 
              browserModel.containsFavorite(favorite);

            final children = <Widget>[];

            if (Util.isIOS() || Util.isMacOS() || Util.isWindows()) {
              children.add(
                _iconButton(
                  Icons.arrow_back, 
                  () => webViewModel.webViewController?.goBack()
                )
              );
            }

            children.addAll([
              _iconButton(
                Icons.arrow_forward, 
                () => webViewModel.webViewController?.goForward()
              ),
              _iconButton(
                isFavorite ? Icons.star : Icons.star_border, 
                () {
                  if (favorite != null) {
                    if (isFavorite) {
                      browserModel.removeFavorite(favorite);
                    } else {
                      browserModel.addFavorite(favorite);
                    }
                  }
                }
              ),
              _iconButton(
                Icons.save_alt_rounded, 
                () async => _saveAsWebArchive(context)
              ),
              _iconButton(Icons.info_outline, showUrlInfo),
              _iconButton(
                Icons.file_download, 
                () => Get.to(() => DownloadManagerScreen())
              ),
              _iconButton(
                MaterialCommunityIcons.cellphone_screenshot, 
                takeScreenshotAndShow
              ),
              _iconButton(
                Icons.refresh, 
                () => webViewModel.webViewController?.reload()
              ),
            ]);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: children
            );
          },
        ),
      ),
    );

    items.addAll(
      PopupMenuActions.choices.map(
        (choice) => _buildMenuItem(choice, context)
      )
    );

    return items;
  }

  Widget _iconButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 35.0,
      child: IconButton(
        padding: EdgeInsets.zero, 
        icon: Icon(icon, color: Colors.black), 
        onPressed: onPressed
      ),
    );
  }

  PopupMenuEntry<String> _buildMenuItem(String choice, BuildContext context) {
    switch (choice) {
      case PopupMenuActions.OPEN_NEW_WINDOW:
        return _menuItem(choice, Icons.open_in_new);
        
      case PopupMenuActions.SAVE_WINDOW:
        return CustomPopupMenuItem<String>(
          value: choice,
          child: GetBuilder<WindowModel>(
            builder: (wm) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text(choice),
                  Icon(
                    wm.shouldSave 
                      ? Icons.check_box 
                      : Icons.check_box_outline_blank
                  ),
                ]
              );
            },
          ),
        );
        
      case PopupMenuActions.SAVED_WINDOWS:
        return _menuItem(choice, Icons.window);
        
      case PopupMenuActions.NEW_TAB:
        return _menuItem(choice, Icons.add);
        
      case PopupMenuActions.NEW_INCOGNITO_TAB:
        return _menuItem(choice, MaterialCommunityIcons.incognito);
        
      case PopupMenuActions.FAVORITES:
        return _menuItem(choice, Icons.star, color: Colors.yellow);
        
      case PopupMenuActions.WEB_ARCHIVES:
        return _menuItem(choice, Icons.offline_pin, color: Colors.blue);
        
      case PopupMenuActions.DESKTOP_MODE:
        return CustomPopupMenuItem<String>(
          value: choice,
          child: GetBuilder<WindowModel>(
            builder: (wm) {
              final isDesktopMode = wm.getCurrentTab()?.webViewModel.isDesktopMode ?? 
                false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Text(choice),
                  Icon(
                    isDesktopMode 
                      ? Icons.check_box 
                      : Icons.check_box_outline_blank
                  ),
                ]
              );
            },
          ),
        );
        
      case PopupMenuActions.HISTORY:
        return _menuItem(choice, Icons.history);
        
      case PopupMenuActions.SHARE:
        return _menuItem(choice, Ionicons.logo_whatsapp, color: Colors.green);
        
      case PopupMenuActions.SETTINGS:
        return _menuItem(choice, Icons.settings, color: Colors.grey);
        
      case PopupMenuActions.DEVELOPERS:
        return _menuItem(choice, Icons.developer_mode);
        
      case PopupMenuActions.FIND_ON_PAGE:
        return _menuItem(choice, Icons.search);
        
      
        
      case PopupMenuActions.SNAKE_GAME:
        return _menuItem(choice, Icons.games, color: Colors.orange);
        
      default:
        return PopupMenuItem(value: choice, child: Text(choice));
    }
  }

  CustomPopupMenuItem<String> _menuItem(
    String text, 
    IconData icon, 
    {Color? color}
  ) {
    return CustomPopupMenuItem<String>(
      value: text,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Text(text),
          Icon(icon, color: color ?? Colors.black),
        ]
      ),
    );
  }

  Future<void> handlePopupChoice(String choice) async {
    switch (choice) {
      case PopupMenuActions.OPEN_NEW_WINDOW:
        openNewWindow();
        break;
      case PopupMenuActions.SAVE_WINDOW:
        setShouldSave();
        break;
      case PopupMenuActions.SAVED_WINDOWS:
        showSavedWindows();
        break;
      case PopupMenuActions.NEW_TAB:
        addNewTab();
        break;
      case PopupMenuActions.NEW_INCOGNITO_TAB:
        addNewIncognitoTab();
        break;
      case PopupMenuActions.FAVORITES:
        showFavorites();
        break;
      case PopupMenuActions.HISTORY:
        await showHistory();
        break;
      case PopupMenuActions.WEB_ARCHIVES:
        showWebArchives();
        break;
      case PopupMenuActions.FIND_ON_PAGE:
        _handleFindOnPage();
        break;
      case PopupMenuActions.SHARE:
        share();
        break;
      case PopupMenuActions.DESKTOP_MODE:
        await toggleDesktopMode();
        break;
      case PopupMenuActions.DEVELOPERS:
        Future.delayed(
          const Duration(milliseconds: 300), 
          goToDevelopersPage
        );
        break;
      case PopupMenuActions.SETTINGS:
        Future.delayed(
          const Duration(milliseconds: 300), 
          goToSettingsPage
        );
        break;
   
        break;
      case PopupMenuActions.SNAKE_GAME:
        Future.delayed(
          const Duration(milliseconds: 300), 
          goToSnakeGame
        );
        break;
    }
  }

  void _handleFindOnPage() {
    final webViewModel = currentWebViewModel;
    final isFindEnabled = webViewModel?.settings?.isFindInteractionEnabled ?? 
      false;
    final controller = webViewModel?.findInteractionController;

    if ((Util.isIOS() || Util.isMacOS()) && 
        isFindEnabled && 
        controller != null) {
      controller.presentFindNavigator();
    } else if (showFindOnPage != null) {
      showFindOnPage!();
    }
  }

  Future<void> _saveAsWebArchive(BuildContext context) async {
    final webViewModel = currentWebViewModel;
    if (webViewModel == null) return;
    
    final url = webViewModel.url;
    if (url == null || !url.scheme.startsWith("http")) return;

    final webArchivePath = "$WEB_ARCHIVE_DIR${Platform.pathSeparator}"
        "${url.scheme}-${url.host}${url.path.replaceAll("/", "-")}"
        "${DateTime.now().microsecondsSinceEpoch}."
        "${Util.isAndroid() ? WebArchiveFormat.MHT.toValue() : WebArchiveFormat.WEBARCHIVE.toValue()}";

    final savedPath = await webViewModel.webViewController?.saveWebArchive(
      filePath: webArchivePath, 
      autoname: false
    );

    if (savedPath != null) {
      final archive = WebArchiveModel(
        url: url,
        path: savedPath,
        title: webViewModel.title,
        favicon: webViewModel.favicon,
        timestamp: DateTime.now(),
      );
      browserModel.addWebArchive(url.toString(), archive);
      browserModel.save();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$url saved offline!"))
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to save!"))
      );
    }
  }

  void addNewTab({WebUri? url}) {
    final settings = browserModel.getSettings();

    // Always provide a valid URL - never create a blank tab
    url ??= settings.homePageEnabled && 
        settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    debugPrint('AppBar: Creating new tab with URL: $url');

    final webViewModel = WebViewModel(
      url: url,
      needsToCompleteInitialLoad: false, // Allow immediate loading
    );

    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(), 
        webViewModel: webViewModel
      )
    );
  }

  void addNewIncognitoTab({WebUri? url}) {
    final settings = browserModel.getSettings();

    // Always provide a valid URL - never create a blank tab
    url ??= settings.homePageEnabled && 
        settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    debugPrint('AppBar: Creating new incognito tab with URL: $url');

    final webViewModel = WebViewModel(
      url: url,
      isIncognitoMode: true,
      needsToCompleteInitialLoad: false, // Allow immediate loading
    );

    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(),
        webViewModel: webViewModel,
      )
    );
  }

  void showFavorites() {
    Get.toNamed('/favorites');
    final url = currentWebViewModel?.url?.toString();
    StateManager.saveState('/favorites', url);
  }

  Future<void> showHistory() async {
    Get.toNamed('/history');
    final url = currentWebViewModel?.url?.toString();
    StateManager.saveState('/history', url);
  }

  void showWebArchives() {
    Get.toNamed('/webarchives');
    final url = currentWebViewModel?.url?.toString();
    StateManager.saveState('/webarchives', url);
  }

  void share() {
    final url = currentWebViewModel?.url;
    if (url != null) {
      Share.share(url.toString(), subject: currentWebViewModel?.title);
    }
  }

  void openNewWindow() => browserModel.openWindow(null);

  void setShouldSave() {
    windowModel.shouldSave = !windowModel.shouldSave;
  }

  Future<void> toggleDesktopMode() async {
    final webViewModel = windowModel.getCurrentTab()?.webViewModel;
    final controller = webViewModel?.webViewController;
    if (controller == null) return;

    webViewModel?.isDesktopMode = !(webViewModel.isDesktopMode);

    final settings = await controller.getSettings();
    if (settings != null) {
      settings.preferredContentMode = webViewModel?.isDesktopMode ?? false
          ? UserPreferredContentMode.DESKTOP
          : UserPreferredContentMode.RECOMMENDED;
      await controller.setSettings(settings: settings);
    }
    
    await controller.reload();
    windowModel.update(); // ✅ Trigger UI update
  }

  void showUrlInfo() {
    final webViewModel = currentWebViewModel;
    if (webViewModel?.url == null) return;

    route = CustomPopupDialogPageRoute(
      builder: (_) => CustomPopupDialog(
        child: UrlInfoPopup(
          route: route!,
          transitionDuration: customPopupDialogTransitionDuration,
          onWebViewTabSettingsClicked: goToSettingsPage,
        ),
        transitionDuration: customPopupDialogTransitionDuration,
      ),
    );

    if (Get.context?.mounted ?? false) {
      Navigator.of(Get.context!).push(route!).then((_) {
        if (Get.isRegistered<UrlInfoController>(tag: 'urlInfo')) {
          Get.delete<UrlInfoController>(tag: 'urlInfo');
        }
      });

      // Create controller with tag after route is pushed
      Get.put(
        UrlInfoController(
          route: route!,
          transitionDuration: customPopupDialogTransitionDuration,
          onWebViewTabSettingsClicked: goToSettingsPage,
        ),
        tag: 'urlInfo',
      );
    }
  }

  void goToDevelopersPage() => Get.to(() => const DevelopersPage());

  void goToSettingsPage() => Get.to(() => const SettingsPage());

  void goToSnakeGame() => Get.toNamed('/snake');

  void openProjectPopup() {
    if (Get.context?.mounted ?? false) {
      showGeneralDialog(
        context: Get.context!,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => const ProjectInfoPopup(),
        transitionDuration: const Duration(milliseconds: 300),
      );
    }
  }

  Future<void> takeScreenshotAndShow() async {
    final webViewModel = currentWebViewModel;
    if (webViewModel == null) return;
    
    final screenshot = await webViewModel.webViewController?.takeScreenshot();
    if (screenshot == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      "${dir.path}/screenshot_${DateTime.now().microsecondsSinceEpoch}.png"
    );
    await file.writeAsBytes(screenshot);

    if (!(Get.context?.mounted ?? false)) return;

    await showDialog(
      context: Get.context!,
      builder: (_) => AlertDialog(
        content: Image.memory(screenshot),
        actions: [
          ElevatedButton(
            onPressed: () => Share.shareXFiles([XFile(file.path)]),
            child: const Text("Share"),
          ),
        ],
      ),
    );

    await file.delete();
  }

  void showSavedWindows() {
    // Implementation as needed
  }

}