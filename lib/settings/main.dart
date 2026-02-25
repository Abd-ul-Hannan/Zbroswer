import 'package:flutter/material.dart';
import 'package:flutter_font_icons/flutter_font_icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/settings/cross_platform_settings.dart';
import 'package:zbrowser/settings/unified_settings.dart';
import '../app_bar/custom_app_bar_wrapper.dart';
import '../tools/custom_popup_menu_item.dart';

class PopupSettingsMenuActions {
  static const String RESET_BROWSER_SETTINGS = "Reset Browser Settings";
  static const String RESET_WEBVIEW_SETTINGS = "Reset WebView Settings";

  static const List<String> choices = <String>[
    RESET_BROWSER_SETTINGS,
    RESET_WEBVIEW_SETTINGS,
  ];
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with tag
    final controller = Get.put(
      SettingsPageController(),
      tag: 'settings_page',
      permanent: false,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: CustomAppBarWrapper(
          appBar: AppBar(
            bottom: TabBar(
              onTap: (value) {
                FocusScope.of(context).unfocus();
              },
              tabs: const [
                Tab(
                  text: "General",
                  icon: SizedBox(
                    width: 25,
                    height: 25,
                    child: CircleAvatar(
                      backgroundImage: AssetImage("assets/icon/icon.png"),
                    ),
                  ),
                ),
                Tab(
                  text: "Platform",
                  icon: Icon(Icons.settings, color: Colors.blue),
                ),
              ],
            ),
            title: const Text("Settings"),
            actions: <Widget>[
              PopupMenuButton<String>(
                onSelected: controller.handlePopupChoice,
                itemBuilder: (context) {
                  return const [
                    CustomPopupMenuItem<String>(
                      enabled: true,
                      value: PopupSettingsMenuActions.RESET_BROWSER_SETTINGS,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(PopupSettingsMenuActions.RESET_BROWSER_SETTINGS),
                          Icon(Foundation.web, color: Colors.black),
                        ],
                      ),
                    ),
                    CustomPopupMenuItem<String>(
                      enabled: true,
                      value: PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS),
                          Icon(MaterialIcons.web, color: Colors.black),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            CrossPlatformSettings(),
            UnifiedSettings(),
          ],
        ),
      ),
    );
  }
}

class SettingsPageController extends GetxController {
  BrowserModel get browserModel => Get.find<BrowserModel>();
  WindowModel get windowModel => Get.find<WindowModel>();

  Future<void> handlePopupChoice(String choice) async {
    switch (choice) {
      case PopupSettingsMenuActions.RESET_BROWSER_SETTINGS:
        try {
          browserModel.updateSettings(BrowserSettings());
          await browserModel.save();
          
          // Force immediate UI updates
          browserModel.update();
          update();
          
          Get.snackbar(
            'Success',
            'Browser settings reset successfully',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to reset browser settings: $e',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        break;

      case PopupSettingsMenuActions.RESET_WEBVIEW_SETTINGS:
        try {
          final currentTab = windowModel.getCurrentTab();
          final webViewController = currentTab?.webViewModel.webViewController;

          if (webViewController == null) {
            Get.snackbar(
              'Error',
              'No active tab to reset settings',
              snackPosition: SnackPosition.BOTTOM,
            );
            return;
          }

          await webViewController.setSettings(
            settings: InAppWebViewSettings(
              incognito: currentTab!.webViewModel.isIncognitoMode,
              useOnDownloadStart: true,
              useOnLoadResource: true,
              safeBrowsingEnabled: true,
              allowsLinkPreview: false,
              isFraudulentWebsiteWarningEnabled: true,
            ),
          );

          currentTab.webViewModel.settings = await webViewController.getSettings();
          browserModel.save();
          
          // Trigger rebuild
          currentTab.webViewModel.update();
          
          Get.snackbar(
            'Success',
            'WebView settings reset for current tab',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to reset WebView settings: $e',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        break;
    }
  }
}