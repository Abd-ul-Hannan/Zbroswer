import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomPopupDialog extends StatelessWidget {
  final Widget child;
  final Duration transitionDuration;
  final Color overlayColor;
  final EdgeInsets padding;
  final double? width;
  final Color backgroundColor;
  final BorderRadius? borderRadius;
  final bool dismissible;

  const CustomPopupDialog({
    super.key,
    required this.child,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.overlayColor = const Color(0x80000000),
    this.padding = const EdgeInsets.all(15.0),
    this.width,
    this.backgroundColor = Colors.white,
    this.borderRadius,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        padding: padding,
        width: width ?? Get.width * 0.9,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  /// Show popup dialog
  static Future<T?> show<T>({
    required Widget child,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Color overlayColor = const Color(0x80000000),
    EdgeInsets padding = const EdgeInsets.all(15.0),
    double? width,
    Color backgroundColor = Colors.white,
    BorderRadius? borderRadius,
    bool dismissible = true,
    Curve transitionCurve = Curves.easeInOut,
  }) {
    return Get.dialog<T>(
      CustomPopupDialog(
        transitionDuration: transitionDuration,
        overlayColor: overlayColor,
        padding: padding,
        width: width,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        dismissible: dismissible,
        child: child,
      ),
      barrierDismissible: dismissible,
      barrierColor: overlayColor,
      transitionDuration: transitionDuration,
      transitionCurve: transitionCurve,
    );
  }

  /// Show with custom animation
  static Future<T?> showWithAnimation<T>({
    required Widget child,
    Duration transitionDuration = const Duration(milliseconds: 400),
    Color overlayColor = const Color(0x80000000),
    EdgeInsets padding = const EdgeInsets.all(15.0),
    double? width,
    Color backgroundColor = Colors.white,
    BorderRadius? borderRadius,
    bool dismissible = true,
  }) {
    return Get.dialog<T>(
      CustomPopupDialog(
        transitionDuration: transitionDuration,
        overlayColor: overlayColor,
        padding: padding,
        width: width,
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        dismissible: dismissible,
        child: child,
      ),
      barrierDismissible: dismissible,
      barrierColor: overlayColor,
      transitionDuration: transitionDuration,
      transitionCurve: Curves.elasticOut,
    );
  }

  /// Show bottom sheet style
  static Future<T?> showBottomSheet<T>({
    required Widget child,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Color overlayColor = const Color(0x80000000),
    EdgeInsets padding = const EdgeInsets.all(20.0),
    Color backgroundColor = Colors.white,
    bool dismissible = true,
  }) {
    return Get.bottomSheet<T>(
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: child,
      ),
      isDismissible: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: overlayColor,
      enterBottomSheetDuration: transitionDuration,
      exitBottomSheetDuration: transitionDuration,
    );
  }

  /// Close current dialog
  static void close<T>([T? result]) {
    if (Get.isDialogOpen == true) {
      Get.back<T>(result: result);
    }
  }

  /// Close all dialogs
  static void closeAll() {
    while (Get.isDialogOpen == true) {
      Get.back();
    }
  }
}

// ==================== HELPER EXTENSIONS ====================
extension CustomPopupExtensions on Widget {
  /// Show this widget in a popup dialog
  Future<T?> showAsPopup<T>({
    Duration transitionDuration = const Duration(milliseconds: 300),
    Color overlayColor = const Color(0x80000000),
    EdgeInsets padding = const EdgeInsets.all(15.0),
    double? width,
    Color backgroundColor = Colors.white,
    BorderRadius? borderRadius,
    bool dismissible = true,
  }) {
    return CustomPopupDialog.show<T>(
      child: this,
      transitionDuration: transitionDuration,
      overlayColor: overlayColor,
      padding: padding,
      width: width,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      dismissible: dismissible,
    );
  }

  /// Show this widget in a bottom sheet
  Future<T?> showAsBottomSheet<T>({
    Duration transitionDuration = const Duration(milliseconds: 300),
    Color overlayColor = const Color(0x80000000),
    EdgeInsets padding = const EdgeInsets.all(20.0),
    Color backgroundColor = Colors.white,
    bool dismissible = true,
  }) {
    return CustomPopupDialog.showBottomSheet<T>(
      child: this,
      transitionDuration: transitionDuration,
      overlayColor: overlayColor,
      padding: padding,
      backgroundColor: backgroundColor,
      dismissible: dismissible,
    );
  }
}