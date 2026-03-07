import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/search_engine_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/controllers/theme_controller.dart';
import 'package:zbrowser/utils/util.dart';
import '../tools/project_info_popup.dart';

class SettingsController extends GetxController {
  late final TextEditingController customHomePageController;
  late final TextEditingController customUserAgentController;

  @override
  void onInit() {
    super.onInit();
    customHomePageController = TextEditingController();
    customUserAgentController = TextEditingController();
  }

  @override
  void onClose() {
    customHomePageController.dispose();
    customUserAgentController.dispose();
    super.onClose();
  }

  List<Widget> buildBaseSettings(
      BuildContext context, BrowserSettings settings, BrowserModel browserModel) {
    final windowModel = Get.find<WindowModel>();
    final themeController = Get.find<ThemeController>();

    List<Widget> widgets = [
      const ListTile(title: Text("General Settings"), enabled: false),

      // Dark Mode Toggle
      GetBuilder<ThemeController>(
        builder: (_) => SwitchListTile(
          title: const Text("Dark Mode"),
          subtitle: const Text("Switch between light and dark theme"),
          value: themeController.isDarkMode,
          onChanged: (value) {
            themeController.setTheme(value);
          },
        ),
      ),

      // Search Engine
      GetBuilder<BrowserModel>(
        builder: (_) => ListTile(
          title: const Text("Search Engine"),
          subtitle: Text(settings.searchEngine.name),
          trailing: DropdownButton<SearchEngineModel>(
            hint: const Text("Search Engine"),
            value: settings.searchEngine,
            onChanged: (value) async {
              if (value != null) {
                settings.searchEngine = value;
                browserModel.updateSettings(settings);
                
                Get.snackbar(
                  'Updated',
                  'Search engine changed to ${value.name}',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 1),
                );
              }
            },
            items: SearchEngines.map((searchEngine) {
              return DropdownMenuItem(
                value: searchEngine,
                child: Text(searchEngine.name),
              );
            }).toList(),
          ),
        ),
      ),

      // Home Page
      GetBuilder<BrowserModel>(
        id: 'home_page',
        builder: (_) => ListTile(
          title: const Text("Home page"),
          subtitle: Text(
            settings.homePageEnabled
                ? (settings.customUrlHomePage.isEmpty
                    ? "ON"
                    : settings.customUrlHomePage)
                : "OFF",
          ),
          onTap: () {
            customHomePageController.text = settings.customUrlHomePage;
            Get.dialog(
              AlertDialog(
                contentPadding: const EdgeInsets.all(0.0),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GetBuilder<BrowserModel>(
                      id: 'home_page_dialog',
                      builder: (_) => SwitchListTile(
                        title: Text(settings.homePageEnabled ? "ON" : "OFF"),
                        value: settings.homePageEnabled,
                        onChanged: (value) async {
                          settings.homePageEnabled = value;
                          browserModel.updateSettings(settings);
                          await browserModel.save();
                          browserModel.update(['home_page_dialog']);
                        },
                      ),
                    ),
                    GetBuilder<BrowserModel>(
                      id: 'home_page_dialog',
                      builder: (_) => ListTile(
                        enabled: settings.homePageEnabled,
                        title: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customHomePageController,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                    hintText: 'Custom URL Home Page'),
                                onSubmitted: (value) async {
                                  settings.customUrlHomePage = value.trim();
                                  browserModel.updateSettings(settings);
                                  await browserModel.save();
                                  browserModel.update(['home_page_dialog', 'home_page']);
                                  Get.back();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      // Default User Agent
      FutureBuilder<String>(
        future: InAppWebViewController.getDefaultUserAgent(),
        builder: (context, snapshot) {
          String defaultUA = snapshot.data ?? "";
          return ListTile(
            title: const Text("Default User Agent"),
            subtitle: Text(defaultUA),
            onLongPress: () {
              if (defaultUA.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: defaultUA));
                Get.snackbar(
                  'Copied',
                  'User Agent copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 1),
                );
              }
            },
          );
        },
      ),

      // Debugging Enabled
      GetBuilder<BrowserModel>(
        id: 'debugging',
        builder: (_) => SwitchListTile(
          title: const Text("Debugging Enabled"),
          subtitle: const Text(
            "Enables debugging of web contents loaded into any WebViews of this application. On iOS < 16.4, the debugging mode is always enabled.",
          ),
          value: settings.debuggingEnabled,
          onChanged: (value) async {
            settings.debuggingEnabled = value;
            browserModel.updateSettings(settings);
            await browserModel.save();
            browserModel.update(['debugging']);

            if (windowModel.webViewTabs.isNotEmpty) {
              var webViewModel = windowModel.getCurrentTab()?.webViewModel;
              if (Util.isAndroid()) {
                InAppWebViewController.setWebContentsDebuggingEnabled(value);
              }
              webViewModel?.settings?.isInspectable = value;
              await webViewModel?.webViewController?.setSettings(
                    settings: webViewModel.settings ?? InAppWebViewSettings(),
                  );
              windowModel.saveInfo();
            }
          },
        ),
      ),

      // Package Info
      FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          String desc = "";
          if (snapshot.hasData) {
            var info = snapshot.data!;
            desc =
                "Package Name: ${info.packageName}\nVersion: ${info.version}\nBuild Number: ${info.buildNumber}";
          }
          return ListTile(
            title: const Text("Flutter Browser Package Info"),
            subtitle: Text(desc),
            onLongPress: () {
              if (desc.isNotEmpty) {
                Clipboard.setData(ClipboardData(text: desc));
                Get.snackbar(
                  'Copied',
                  'Package info copied to clipboard',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 1),
                );
              }
            },
          );
        },
      ),

      // Project Info
      
    ];

    // Android-specific WebView Package Info
    if (Util.isAndroid()) {
      widgets.add(
        FutureBuilder<WebViewPackageInfo?>(
          future: InAppWebViewController.getCurrentWebViewPackage(),
          builder: (context, snapshot) {
            String desc = "";
            if (snapshot.hasData && snapshot.data != null) {
              var info = snapshot.data!;
              desc = "${info.packageName ?? ""} - ${info.versionName ?? ""}";
            }
            return ListTile(
              title: const Text("WebView Package Info"),
              subtitle: Text(desc),
              onLongPress: () {
                if (desc.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: desc));
                  Get.snackbar(
                    'Copied',
                    'WebView info copied to clipboard',
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 1),
                  );
                }
              },
            );
          },
        ),
      );
    }

    return widgets;
  }

  List<Widget> buildWebViewTabSettings(BuildContext context) {
    final windowModel = Get.find<WindowModel>();
    final currentTab = windowModel.getCurrentTab();
    if (currentTab == null) {
      return [const ListTile(title: Text("No current tab available"), enabled: false)];
    }
    
    final currentWebViewModel = currentTab.webViewModel;
    final webViewController = currentWebViewModel.webViewController;

    return [
      const ListTile(title: Text("Current WebView Settings"), enabled: false),

      // JavaScript Enabled
      GetBuilder<WebViewModel>(
        id: 'js_enabled',
        builder: (_) => _switchTile(
          title: "JavaScript Enabled",
          subtitle: "Sets whether the WebView should enable JavaScript.",
          value: currentWebViewModel.settings?.javaScriptEnabled ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.javaScriptEnabled =
                  !(currentWebViewModel.settings?.javaScriptEnabled ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Cache Enabled
      GetBuilder<WebViewModel>(
        id: 'cache_enabled',
        builder: (_) => _switchTile(
          title: "Cache Enabled",
          subtitle: "Sets whether the WebView should use browser caching.",
          value: currentWebViewModel.settings?.cacheEnabled ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.cacheEnabled =
                  !(currentWebViewModel.settings?.cacheEnabled ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Custom User Agent
      GetBuilder<WebViewModel>(
        id: 'user_agent',
        builder: (_) {
          String ua = currentWebViewModel.settings?.userAgent ?? "";
          return ListTile(
            title: const Text("Custom User Agent"),
            subtitle: Text(ua.isNotEmpty ? ua : "Set a custom user agent ..."),
            onTap: () {
              customUserAgentController.text = ua;
              Get.dialog(
                AlertDialog(
                  contentPadding: const EdgeInsets.all(0.0),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: customUserAgentController,
                                keyboardType: TextInputType.multiline,
                                maxLines: null,
                                textInputAction: TextInputAction.go,
                                decoration: const InputDecoration(
                                    hintText: 'Custom User Agent'),
                                onSubmitted: (value) async {
                                  if (currentWebViewModel.settings != null) {
                                    currentWebViewModel.settings!.userAgent = value.trim();
                                    await _applySettings(currentWebViewModel, webViewController, windowModel);
                                  }
                                  Get.back();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // Support Zoom
      GetBuilder<WebViewModel>(
        id: 'support_zoom',
        builder: (_) => _switchTile(
          title: "Support Zoom",
          subtitle:
              "Sets whether the WebView should not support zooming using its on-screen zoom controls and gestures.",
          value: currentWebViewModel.settings?.supportZoom ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.supportZoom =
                  !(currentWebViewModel.settings?.supportZoom ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Media Playback Requires User Gesture
      GetBuilder<WebViewModel>(
        id: 'media_gesture',
        builder: (_) => _switchTile(
          title: "Media Playback Requires User Gesture",
          subtitle:
              "Sets whether the WebView should prevent HTML5 audio or video from autoplaying.",
          value: currentWebViewModel.settings?.mediaPlaybackRequiresUserGesture ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.mediaPlaybackRequiresUserGesture =
                  !(currentWebViewModel.settings?.mediaPlaybackRequiresUserGesture ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Vertical ScrollBar Enabled
      GetBuilder<WebViewModel>(
        id: 'vertical_scroll',
        builder: (_) => _switchTile(
          title: "Vertical ScrollBar Enabled",
          subtitle: "Sets whether the vertical scrollbar should be drawn or not.",
          value: currentWebViewModel.settings?.verticalScrollBarEnabled ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.verticalScrollBarEnabled =
                  !(currentWebViewModel.settings?.verticalScrollBarEnabled ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Horizontal ScrollBar Enabled
      GetBuilder<WebViewModel>(
        id: 'horizontal_scroll',
        builder: (_) => _switchTile(
          title: "Horizontal ScrollBar Enabled",
          subtitle: "Sets whether the horizontal scrollbar should be drawn or not.",
          value: currentWebViewModel.settings?.horizontalScrollBarEnabled ?? true,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.horizontalScrollBarEnabled =
                  !(currentWebViewModel.settings?.horizontalScrollBarEnabled ?? true);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Disable Vertical Scroll
      GetBuilder<WebViewModel>(
        id: 'disable_vertical',
        builder: (_) => _switchTile(
          title: "Disable Vertical Scroll",
          subtitle: "Sets whether vertical scroll should be enabled or not.",
          value: currentWebViewModel.settings?.disableVerticalScroll ?? false,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.disableVerticalScroll =
                  !(currentWebViewModel.settings?.disableVerticalScroll ?? false);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Disable Horizontal Scroll
      GetBuilder<WebViewModel>(
        id: 'disable_horizontal',
        builder: (_) => _switchTile(
          title: "Disable Horizontal Scroll",
          subtitle: "Sets whether horizontal scroll should be enabled or not.",
          value: currentWebViewModel.settings?.disableHorizontalScroll ?? false,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.disableHorizontalScroll =
                  !(currentWebViewModel.settings?.disableHorizontalScroll ?? false);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Disable Context Menu
      GetBuilder<WebViewModel>(
        id: 'context_menu',
        builder: (_) => _switchTile(
          title: "Disable Context Menu",
          subtitle: "Sets whether context menu should be enabled or not.",
          value: currentWebViewModel.settings?.disableContextMenu ?? false,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.disableContextMenu =
                  !(currentWebViewModel.settings?.disableContextMenu ?? false);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Minimum Font Size
      GetBuilder<WebViewModel>(
        id: 'min_font',
        builder: (_) {
          int fontSize = currentWebViewModel.settings?.minimumFontSize ?? 8;
          return ListTile(
            title: const Text("Minimum Font Size"),
            subtitle: const Text("Sets the minimum font size."),
            trailing: SizedBox(
              width: 70,
              child: TextFormField(
                key: ValueKey(fontSize),
                initialValue: fontSize.toString(),
                keyboardType: TextInputType.number,
                onFieldSubmitted: (value) async {
                  int? newSize = int.tryParse(value);
                  if (newSize != null && currentWebViewModel.settings != null) {
                    currentWebViewModel.settings!.minimumFontSize = newSize;
                    await _applySettings(currentWebViewModel, webViewController, windowModel);
                  }
                },
              ),
            ),
          );
        },
      ),

      // Allow File Access From File URLs
      GetBuilder<WebViewModel>(
        id: 'file_access',
        builder: (_) => _switchTile(
          title: "Allow File Access From File URLs",
          subtitle:
              "Sets whether JavaScript running in the context of a file scheme URL should be allowed to access content from other file scheme URLs.",
          value: currentWebViewModel.settings?.allowFileAccessFromFileURLs ?? false,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.allowFileAccessFromFileURLs =
                  !(currentWebViewModel.settings?.allowFileAccessFromFileURLs ?? false);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),

      // Allow Universal Access From File URLs
      GetBuilder<WebViewModel>(
        id: 'universal_access',
        builder: (_) => _switchTile(
          title: "Allow Universal Access From File URLs",
          subtitle:
              "Sets whether JavaScript running in the context of a file scheme URL should be allowed to access content from any origin.",
          value: currentWebViewModel.settings?.allowUniversalAccessFromFileURLs ?? false,
          toggle: () {
            if (currentWebViewModel.settings != null) {
              currentWebViewModel.settings!.allowUniversalAccessFromFileURLs =
                  !(currentWebViewModel.settings?.allowUniversalAccessFromFileURLs ?? false);
            }
          },
          onUpdate: () => _applySettings(currentWebViewModel, webViewController, windowModel),
        ),
      ),
    ];
  }

  // Helper for repeated SwitchListTile
  SwitchListTile _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback toggle,
    required Future<void> Function() onUpdate,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: (_) async {
        toggle();
        await onUpdate();
      },
    );
  }

  // Apply settings to WebView
  Future<void> _applySettings(
    WebViewModel webViewModel,
    InAppWebViewController? controller,
    WindowModel windowModel,
  ) async {
    try {
      await controller?.setSettings(
          settings: webViewModel.settings ?? InAppWebViewSettings());
      webViewModel.settings = await controller?.getSettings();
      windowModel.saveInfo();
      
      // Trigger update for all relevant GetBuilders
      webViewModel.update();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to apply settings: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Show Project Info Popup
  void _showProjectInfo(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => const ProjectInfoPopup(),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}