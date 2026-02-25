import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/app_bar/desktop_app_bar.dart';
import 'package:zbrowser/app_bar/find_on_page_app_bar.dart';
import 'package:zbrowser/app_bar/webview_tab_app_bar.dart';
import 'package:zbrowser/utils/util.dart';

// ==================== CONTROLLER ====================
class BrowserAppBarController extends GetxController {
  final isFindingOnPage = false.obs;

  void showFindOnPage() {
    if (!Get.isRegistered<FindOnPageController>(tag: 'findOnPage')) {
      Get.put(
        FindOnPageController(hideFindOnPage: hideFindOnPage),
        tag: 'findOnPage',
      );
    }
    isFindingOnPage.value = true;
  }

  void hideFindOnPage() {
    if (Get.isRegistered<FindOnPageController>(tag: 'findOnPage')) {
      Get.delete<FindOnPageController>(tag: 'findOnPage');
    }
    isFindingOnPage.value = false;
  }

  @override
  void onClose() {
    // Clean up FindOnPageController if exists
    if (Get.isRegistered<FindOnPageController>(tag: 'findOnPage')) {
      Get.delete<FindOnPageController>(tag: 'findOnPage');
    }
    super.onClose();
  }
}

// ==================== WIDGET ====================
class BrowserAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrowserAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(
        Util.isMobile() ? kToolbarHeight : 90.0,
      );

  @override
  Widget build(BuildContext context) {
    // Get or create controller
    final controller = Get.put(BrowserAppBarController());

    return Obx(() {
      final List<Widget> children = [];

      if (Util.isDesktop()) {
        children.add(const DesktopAppBar());
      }

      children.add(
        controller.isFindingOnPage.value
            ? FindOnPageAppBar(
                hideFindOnPage: controller.hideFindOnPage,
              )
            : WebViewTabAppBar(
                showFindOnPage: controller.showFindOnPage,
              ),
      );

      return Column(children: children);
    });
  }
}

// ==================== ALTERNATIVE: MORE ORGANIZED ====================
class BrowserAppBarControllerV2 extends GetxController {
  final isFindingOnPage = false.obs;
  FindOnPageController? _findOnPageController;

  void showFindOnPage() {
    if (_findOnPageController == null) {
      _findOnPageController = Get.put(
        FindOnPageController(hideFindOnPage: hideFindOnPage),
        tag: 'findOnPage',
      );
    }
    isFindingOnPage.value = true;
  }

  void hideFindOnPage() {
    if (_findOnPageController != null) {
      Get.delete<FindOnPageController>(tag: 'findOnPage');
      _findOnPageController = null;
    }
    isFindingOnPage.value = false;
  }

  @override
  void onClose() {
    hideFindOnPage();
    super.onClose();
  }
}

class BrowserAppBarV2 extends StatelessWidget implements PreferredSizeWidget {
  const BrowserAppBarV2({super.key});

  @override
  Size get preferredSize => Size.fromHeight(
        Util.isMobile() ? kToolbarHeight : 90.0,
      );

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BrowserAppBarControllerV2());

    return Obx(() {
      return Column(
        children: [
          if (Util.isDesktop()) const DesktopAppBar(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: controller.isFindingOnPage.value
                ? FindOnPageAppBar(
                    key: const ValueKey('findOnPage'),
                    hideFindOnPage: controller.hideFindOnPage,
                  )
                : WebViewTabAppBar(
                    key: const ValueKey('webViewTab'),
                    showFindOnPage: controller.showFindOnPage,
                  ),
          ),
        ],
      );
    });
  }
}

// ==================== ADVANCED: WITH BETTER STATE MANAGEMENT ====================
enum AppBarMode { normal, findOnPage }

class BrowserAppBarControllerV3 extends GetxController {
  final currentMode = AppBarMode.normal.obs;
  FindOnPageController? _findOnPageController;

  bool get isFindingOnPage => currentMode.value == AppBarMode.findOnPage;

  void switchToFindOnPage() {
    if (currentMode.value == AppBarMode.findOnPage) return;

    _findOnPageController = Get.put(
      FindOnPageController(hideFindOnPage: switchToNormal),
      tag: 'findOnPage',
    );
    currentMode.value = AppBarMode.findOnPage;
  }

  void switchToNormal() {
    if (currentMode.value == AppBarMode.normal) return;

    if (_findOnPageController != null) {
      Get.delete<FindOnPageController>(tag: 'findOnPage');
      _findOnPageController = null;
    }
    currentMode.value = AppBarMode.normal;
  }

  void toggleMode() {
    if (currentMode.value == AppBarMode.normal) {
      switchToFindOnPage();
    } else {
      switchToNormal();
    }
  }

  @override
  void onClose() {
    switchToNormal();
    super.onClose();
  }
}

class BrowserAppBarV3 extends StatelessWidget implements PreferredSizeWidget {
  const BrowserAppBarV3({super.key});

  @override
  Size get preferredSize => Size.fromHeight(
        Util.isMobile() ? kToolbarHeight : 90.0,
      );

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(BrowserAppBarControllerV3());

    return Obx(() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Desktop app bar (only on desktop)
          if (Util.isDesktop()) const DesktopAppBar(),
          
          // Main content with smooth transition
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: _buildCurrentAppBar(controller),
          ),
        ],
      );
    });
  }

  Widget _buildCurrentAppBar(BrowserAppBarControllerV3 controller) {
    switch (controller.currentMode.value) {
      case AppBarMode.findOnPage:
        return FindOnPageAppBar(
          key: const ValueKey('findOnPage'),
          hideFindOnPage: controller.switchToNormal,
        );
      case AppBarMode.normal:
      default:
        return WebViewTabAppBar(
          key: const ValueKey('webViewTab'),
          showFindOnPage: controller.switchToFindOnPage,
        );
    }
  }
}