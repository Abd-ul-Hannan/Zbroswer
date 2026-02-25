import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zbrowser/controllers/DownloadController.dart';
import 'package:zbrowser/utils/javascript_console_result.dart';
import 'package:zbrowser/dialogs+action/long_press_alert_dialog.dart';
import 'package:zbrowser/main.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/utils/util.dart';
import '../controllers/WebViewTabController.dart';

class WebViewTab extends StatelessWidget {
  final WebViewModel webViewModel;

  const WebViewTab({super.key, required this.webViewModel});

  @override
  Widget build(BuildContext context) {
    // Use consistent tag generation
    final tag = 'webview_tab_${webViewModel.hashCode}';

    // Get or create controller safely
    final controller = Get.put(
      WebViewTabController(webViewModel: webViewModel),
      tag: tag,
      permanent: false,
    );

    return CallbackShortcuts(
      bindings: {
        // Support multiple reload shortcuts
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyR): controller.reload,
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): controller.reload,
        LogicalKeySet(LogicalKeyboardKey.f5): controller.reload,
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: controller.buildWebView(),
        ),
      ),
    );
  }
}