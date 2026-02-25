import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/search_engine_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/utils/util.dart';
import '../tools/project_info_popup.dart';
import 'SettingsController.dart';

class CrossPlatformSettings extends StatelessWidget {
  const CrossPlatformSettings({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller with tag
    final controller = Get.put(
      SettingsController(),
      tag: 'cross_platform_settings',
      permanent: false,
    );

    return GetBuilder<BrowserModel>(
      builder: (browserModel) {
        final settings = browserModel.getSettings();
        
        return GetBuilder<WindowModel>(
          builder: (windowModel) {
            List<Widget> children = controller.buildBaseSettings(
              context,
              settings,
              browserModel,
            );

            if (windowModel.webViewTabs.isNotEmpty) {
              children.addAll(controller.buildWebViewTabSettings(context));
            }

            return ListView(children: children);
          },
        );
      },
    );
  }
}
