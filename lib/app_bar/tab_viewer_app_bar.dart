import 'package:flutter/material.dart';
import 'package:flutter_font_icons/flutter_font_icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'package:zbrowser/controllers/TabViewerController.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/settings/main.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import '../tools/custom_popup_menu_item.dart';
import '../dialogs+action/tab_viewer_popup_menu_actions.dart';

class TabViewerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TabViewerAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Proper controller initialization with tag
    final controller = Get.put(
      TabViewerAppBarController(),
      tag: 'tab_viewer_appbar',
    );

    return AppBar(
      titleSpacing: 10.0,
      leading: controller.buildAddTabButton(),
      actions: controller.buildActionsMenu(),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class TabViewerAppBarController extends GetxController {
  final GlobalKey tabInkWellKey = GlobalKey();
  
  // ✅ FIXED: Getters instead of late initialization
  BrowserModel get browserModel => Get.find<BrowserModel>();
  WindowModel get windowModel => Get.find<WindowModel>();
  BrowserSettings get settings => browserModel.getSettings();

  Widget buildAddTabButton() {
    return IconButton(
      icon: const Icon(Icons.add),
      onPressed: addNewTab,
    );
  }

  List<Widget> buildActionsMenu() {
    return [
      // ✅ FIXED: Use GetBuilder for reactive tab count
      GetBuilder<WindowModel>(
        builder: (wm) {
          return InkWell(
            key: tabInkWellKey,
            onTap: () {
              if (wm.webViewTabs.isNotEmpty) {
                browserModel.showTabScroller.value = 
                  !browserModel.showTabScroller.value;
              } else {
                browserModel.showTabScroller.value = false;
              }
            },
            child: Padding(
              padding: settings.homePageEnabled
                  ? const EdgeInsets.only(
                      left: 20.0, 
                      top: 15.0, 
                      right: 10.0, 
                      bottom: 15.0
                    )
                  : const EdgeInsets.only(
                      left: 10.0, 
                      top: 15.0, 
                      right: 10.0, 
                      bottom: 15.0
                    ),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 2.0),
                  shape: BoxShape.rectangle,
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
            ),
          );
        },
      ),
      PopupMenuButton<String>(
        onSelected: handlePopupChoice,
        itemBuilder: (_) => _buildPopupMenuItems(),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildPopupMenuItems() {
    return TabViewerPopupMenuActions.choices.map((choice) {
      switch (choice) {
        case TabViewerPopupMenuActions.NEW_TAB:
          return _buildMenuItem(
            choice,
            const Icon(Icons.add, color: Colors.black),
            enabled: true,
          );
          
        case TabViewerPopupMenuActions.NEW_INCOGNITO_TAB:
          return _buildMenuItem(
            choice,
            const Icon(MaterialCommunityIcons.incognito, color: Colors.black),
            enabled: true,
          );
          
        case TabViewerPopupMenuActions.CLOSE_ALL_TABS:
          // ✅ FIXED: Reactive enabled state
          return CustomPopupMenuItem<String>(
            value: choice,
            child: GetBuilder<WindowModel>(
              builder: (wm) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      choice,
                      style: TextStyle(
                        color: wm.webViewTabs.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                    ),
                    Icon(
                      Icons.close,
                      color: wm.webViewTabs.isNotEmpty ? Colors.black : Colors.grey,
                    ),
                  ],
                );
              },
            ),
          );
          
        case TabViewerPopupMenuActions.SETTINGS:
          return _buildMenuItem(
            choice,
            const Icon(Icons.settings, color: Colors.grey),
            enabled: true,
          );
          
        default:
          return CustomPopupMenuItem<String>(
            value: choice,
            child: Text(choice),
          );
      }
    }).toList();
  }

  // ✅ FIXED: Helper method to build menu items
  CustomPopupMenuItem<String> _buildMenuItem(
    String choice,
    Widget icon, {
    required bool enabled,
  }) {
    return CustomPopupMenuItem<String>(
      enabled: enabled,
      value: choice,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(choice),
          icon,
        ],
      ),
    );
  }

  void handlePopupChoice(String choice) {
    switch (choice) {
      case TabViewerPopupMenuActions.NEW_TAB:
        addNewTab();
        break;
      case TabViewerPopupMenuActions.NEW_INCOGNITO_TAB:
        addNewIncognitoTab();
        break;
      case TabViewerPopupMenuActions.CLOSE_ALL_TABS:
        closeAllTabs();
        break;
      case TabViewerPopupMenuActions.SETTINGS:
        goToSettingsPage();
        break;
    }
  }

  void addNewTab({WebUri? url}) {
    url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    // ✅ FIXED: Clean up in proper order
    browserModel.showTabScroller.value = false;
    
    if (Get.isRegistered<TabViewerController>()) {
      Get.delete<TabViewerController>();
    }

    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(), 
        webViewModel: WebViewModel(url: url)
      ),
    );
  }

  void addNewIncognitoTab({WebUri? url}) {
    url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    // ✅ FIXED: Clean up in proper order
    browserModel.showTabScroller.value = false;
    
    if (Get.isRegistered<TabViewerController>()) {
      Get.delete<TabViewerController>();
    }

    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(),
        webViewModel: WebViewModel(url: url, isIncognitoMode: true),
      ),
    );
  }

  void closeAllTabs() {
    // ✅ FIXED: Clean up in proper order
    browserModel.showTabScroller.value = false;
    
    if (Get.isRegistered<TabViewerController>()) {
      Get.delete<TabViewerController>();
    }
    
    windowModel.closeAllTabs();
  }

  void goToSettingsPage() {
    Get.to(() => const SettingsPage());
  }
  
  // ✅ FIXED: Add cleanup method
  @override
  void onClose() {
    // Clean up any resources if needed
    super.onClose();
  }
}