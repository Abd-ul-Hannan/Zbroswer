import 'package:collection/collection.dart';
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:window_manager_plus/window_manager_plus.dart';

import '../tools/custom_image.dart';
import '../models/browser_model.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import '../utils/util.dart';
import '../screens/webview_tab.dart';

class DesktopAppBar extends StatelessWidget {
  final bool showTabs;

  const DesktopAppBar({super.key, this.showTabs = true});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Single controller instance with proper tag
    final controller = Get.put(
      DesktopAppBarController(showTabs: showTabs),
      tag: 'desktop_appbar',
    );

    return GetBuilder<DesktopAppBarController>(
      tag: 'desktop_appbar',
      builder: (ctrl) {
        // ✅ FIXED: Get WindowModel once at top level
        final windowModel = Get.find<WindowModel>();

        final tabSelectors = ctrl.buildTabSelectors(windowModel);
        final windowActions = ctrl.buildWindowActions();

        final children = [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 100
            ),
            child: IntrinsicWidth(
              child: Row(
                children: [
                  ...windowActions,
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: tabSelectors.isNotEmpty
                            ? tabSelectors
                            : [const SizedBox(height: 30)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  if (showTabs)
                    IconButton(
                      onPressed: ctrl.addNewTab,
                      constraints: const BoxConstraints(
                        maxWidth: 25, 
                        maxHeight: 25
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.add, 
                        size: 15, 
                        color: Colors.white
                      ),
                    ),
                ],
              ),
            ),
          ),
          Flexible(
            child: MouseRegion(
              hitTestBehavior: HitTestBehavior.opaque,
              onEnter: (_) => ctrl.onTitleBarEnter(),
              onExit: (_) => ctrl.onTitleBarExit(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => WindowManagerPlus.current.maximize(),
                child: showTabs
                    ? ContextMenuRegion(
                        behavior: const [ContextMenuShowBehavior.secondaryTap],
                        contextMenu: GenericContextMenu(
                          buttonConfigs: [
                            ContextMenuButtonConfig(
                              "New Tab",
                              onPressed: ctrl.addNewTab,
                            ),
                            ContextMenuButtonConfig(
                              "Close All",
                              onPressed: () => windowModel.closeAllTabs(),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          height: 30, 
                          width: double.infinity
                        ),
                      )
                    : const SizedBox(height: 30, width: double.infinity),
              ),
            ),
          ),
          if (showTabs)
            OpenTabsViewer(webViewTabs: windowModel.webViewTabs),
        ];

        return Container(
          color: Theme.of(context).colorScheme.primary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: children,
          ),
        );
      },
    );
  }
}

class DesktopAppBarController extends GetxController {
  final bool showTabs;

  DesktopAppBarController({this.showTabs = true});

  final RxBool isTitleBarHovered = false.obs;

  List<Widget> buildTabSelectors(WindowModel windowModel) {
    if (!showTabs) return [];

    return windowModel.webViewTabs.mapIndexed((index, webViewTab) {
      final currentIndex = windowModel.getCurrentTabIndex();

      return Flexible(
        flex: 1,
        fit: FlexFit.loose,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: WebViewTabSelector(
                  tab: webViewTab, 
                  index: index
                ),
              ),
              SizedBox(
                height: 15,
                child: VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: index == currentIndex - 1 || index == currentIndex
                      ? Colors.transparent
                      : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> buildWindowActions() {
    if (Util.isWindows()) return [];

    return [
      const SizedBox(width: 8),
      IconButton(
        onPressed: () => WindowManagerPlus.current.close(),
        constraints: const BoxConstraints(maxWidth: 13, maxHeight: 13),
        padding: EdgeInsets.zero,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.red),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? Colors.black45
                : Colors.red
          ),
        ),
        icon: const Icon(Icons.close, size: 10),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () async {
          if (!(await WindowManagerPlus.current.isFullScreen())) {
            WindowManagerPlus.current.minimize();
          }
        },
        constraints: const BoxConstraints(maxWidth: 13, maxHeight: 13),
        padding: EdgeInsets.zero,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.amber),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? Colors.black45
                : Colors.amber
          ),
        ),
        icon: const Icon(Icons.remove, size: 10),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: () async {
          WindowManagerPlus.current.setFullScreen(
            !(await WindowManagerPlus.current.isFullScreen())
          );
        },
        constraints: const BoxConstraints(maxWidth: 13, maxHeight: 13),
        padding: EdgeInsets.zero,
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.green),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? Colors.black45
                : Colors.green
          ),
        ),
        icon: const Icon(Icons.open_in_full, size: 10),
      ),
      const SizedBox(width: 8),
    ];
  }

  void onTitleBarEnter() {
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(true);
    }
    isTitleBarHovered.value = true;
  }

  void onTitleBarExit() {
    if (!Util.isWindows()) {
      WindowManagerPlus.current.setMovable(false);
    }
  }

  void addNewTab() {
    final browserModel = Get.find<BrowserModel>();
    final windowModel = Get.find<WindowModel>();
    final settings = browserModel.getSettings();

    windowModel.addTab(WebViewTab(
      key: GlobalKey(),
      webViewModel: WebViewModel(url: WebUri(settings.searchEngine.url)),
    ));
  }
}

class WebViewTabSelector extends StatelessWidget {
  final WebViewTab tab;
  final int index;

  const WebViewTabSelector({
    super.key, 
    required this.tab, 
    required this.index
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: GetBuilder instead of Obx for better performance
    return GetBuilder<WindowModel>(
      builder: (windowModel) {
        final isCurrentTab = windowModel.getCurrentTabIndex() == index;

        // ✅ FIXED: Listen to specific webViewModel changes
        return Obx(() {
          final url = tab.webViewModel.url;
          final tabName = tab.webViewModel.title ?? 
            url?.toString() ?? 
            'New Tab';
          
          final tooltipText = '$tabName\n${(url?.host ?? '').isEmpty ? url?.toString() : url?.host}'.trim();

          final faviconUrl = tab.webViewModel.favicon != null
              ? tab.webViewModel.favicon!.url
              : (url != null && ["http", "https"].contains(url.scheme)
                  ? Uri.parse("${url.origin}/favicon.ico")
                  : null);

          return MouseRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => windowModel.showTab(index),
              child: ContextMenuRegion(
                contextMenu: GenericContextMenu(
                  buttonConfigs: [
                    ContextMenuButtonConfig(
                      "Reload",
                      onPressed: () => tab.webViewModel.webViewController?.reload(),
                    ),
                    ContextMenuButtonConfig(
                      "Duplicate",
                      onPressed: () {
                        if (tab.webViewModel.url != null) {
                          windowModel.addTab(WebViewTab(
                            key: GlobalKey(),
                            webViewModel: WebViewModel(url: tab.webViewModel.url),
                          ));
                        }
                      },
                    ),
                    ContextMenuButtonConfig(
                      "Close",
                      onPressed: () => windowModel.closeTab(index),
                    ),
                  ],
                ),
                child: Container(
                  height: 30,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 250),
                  padding: const EdgeInsets.only(right: 5.0),
                  decoration: isCurrentTab
                      ? BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(5)
                          ),
                        )
                      : null,
                  child: Tooltip(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                    richMessage: WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Text(
                          tooltipText,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    waitDuration: const Duration(milliseconds: 500),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: CustomImage(
                                  url: faviconUrl,
                                  maxWidth: 20.0,
                                  height: 20.0,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  tabName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isCurrentTab ? null : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => windowModel.closeTab(index),
                          constraints: const BoxConstraints(
                            maxWidth: 20, 
                            maxHeight: 20
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.cancel,
                            color: isCurrentTab ? null : Colors.white,
                            size: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

class OpenTabsViewer extends StatelessWidget {
  final List<WebViewTab> webViewTabs;

  const OpenTabsViewer({super.key, required this.webViewTabs});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Proper controller initialization with tag
    final controller = Get.put(
      OpenTabsViewerController(webViewTabs: webViewTabs),
      tag: 'open_tabs_viewer',
    );

    return Container(
      padding: const EdgeInsets.all(4.0),
      child: MenuAnchor(
        builder: (context, menuController, child) {
          return IconButton(
            onPressed: () {
              if (menuController.isOpen) {
                menuController.close();
              } else {
                // ✅ Refresh tabs when opening
                controller.filterTabs();
                menuController.open();
              }
            },
            constraints: const BoxConstraints(maxWidth: 25, maxHeight: 25),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.keyboard_arrow_down,
              size: 15,
              color: Colors.white,
            ),
          );
        },
        menuChildren: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200),
            child: TextFormField(
              controller: controller.searchController,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelLarge,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search open tabs',
                contentPadding: EdgeInsets.only(top: 15),
                isDense: true,
              ),
              onChanged: (_) => controller.filterTabs(),
            ),
          ),
          MenuItemButton(
            onPressed: null,
            child: Text(
              webViewTabs.isEmpty ? 'No tabs open' : 'Tabs open',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          // ✅ FIXED: Use Obx for filtered tabs
          ...controller._buildFilteredTabItems(context),
        ],
      ),
    );
  }
}

class OpenTabsViewerController extends GetxController {
  final List<WebViewTab> webViewTabs;
  final TextEditingController searchController = TextEditingController();

  OpenTabsViewerController({required this.webViewTabs});

  final RxList<WebViewTab> filteredTabs = <WebViewTab>[].obs;

  @override
  void onInit() {
    super.onInit();
    filteredTabs.assignAll(webViewTabs);
    searchController.addListener(filterTabs);
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  void filterTabs() {
    final search = searchController.text.toLowerCase().trim();
    if (search.isEmpty) {
      filteredTabs.assignAll(webViewTabs);
    } else {
      filteredTabs.assignAll(webViewTabs.where((tab) {
        final titleMatch = tab.webViewModel.title
          ?.toLowerCase()
          .contains(search) ?? false;
        final urlMatch = tab.webViewModel.url
          ?.toString()
          .toLowerCase()
          .contains(search) ?? false;
        return titleMatch || urlMatch;
      }));
    }
    update(); // ✅ Trigger UI update
  }

  // ✅ FIXED: Separate method for building filtered tab items
  List<Widget> _buildFilteredTabItems(BuildContext context) {
    return filteredTabs.map((w) {
      final url = w.webViewModel.url;
      final title = (w.webViewModel.title ?? '').isNotEmpty
          ? w.webViewModel.title!
          : 'New Tab';
      final subtitle = (url?.host ?? '').isEmpty 
          ? url?.toString() 
          : url?.host;

      final diffTime = DateTime.now().difference(w.webViewModel.lastOpenedTime);
      String diffTimeSubtitle = 'now';
      
      if (diffTime.inDays > 0) {
        diffTimeSubtitle = '${diffTime.inDays} ${diffTime.inDays == 1 ? 'day' : 'days'} ago';
      } else if (diffTime.inMinutes > 0) {
        diffTimeSubtitle = '${diffTime.inMinutes} min ago';
      } else if (diffTime.inSeconds > 0) {
        diffTimeSubtitle = '${diffTime.inSeconds} sec ago';
      }

      final faviconUrl = w.webViewModel.favicon != null
          ? w.webViewModel.favicon!.url
          : (url != null && ["http", "https"].contains(url.scheme)
              ? Uri.parse("${url.origin}/favicon.ico")
              : null);

      return MenuItemButton(
        onPressed: () {
          final windowModel = Get.find<WindowModel>();
          windowModel.showTab(webViewTabs.indexOf(w));
        },
        leadingIcon: Container(
          padding: const EdgeInsets.all(8),
          child: CustomImage(url: faviconUrl, maxWidth: 15, height: 15),
        ),
        trailingIcon: IconButton(
          onPressed: () {
            final windowModel = Get.find<WindowModel>();
            windowModel.closeTab(webViewTabs.indexOf(w));
          },
          constraints: const BoxConstraints(maxWidth: 25, maxHeight: 25),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.cancel, size: 15),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      subtitle ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    " - $diffTimeSubtitle",
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}