import 'package:flutter/material.dart';
import 'package:flutter_font_icons/flutter_font_icons.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:zbrowser/models/webview_model.dart';

import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'animated_flutter_browser_logo.dart';

class ProjectInfoPopup extends StatelessWidget {
  const ProjectInfoPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final windowModel = Get.find<WindowModel>();

    final List<Widget> commonChildren = [
      RichText(
        text: const TextSpan(
          style: TextStyle(color: Colors.black, fontSize: 16),
          children: [
            TextSpan(text: "Do you like this project? Give a "),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(Icons.star, size: 25, color: Colors.yellow),
            ),
            TextSpan(text: " to"),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _buildGithubButton(
        context: context,
        windowModel: windowModel,
        repo: "pichillilorenzo/flutter_inappwebview",
        label: "flutter_inappwebview",
      ),
      const SizedBox(height: 10),
      RichText(
        text: const TextSpan(
          style: TextStyle(color: Colors.black, fontSize: 16),
          children: [TextSpan(text: "and to")],
        ),
      ),
      const SizedBox(height: 10),
      _buildGithubButton(
        context: context,
        windowModel: windowModel,
        repo: "pichillilorenzo/flutter_browser_app",
        label: "flutter_browser_app",
      ),
      const SizedBox(height: 20),
      const SizedBox(
        width: 250.0,
        child: Text(
          "Also, if you want, you can support these projects with a donation. Thanks!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
    ];

    // iOS/macOS specific back button
    if (Util.isIOS() || Util.isMacOS()) {
      commonChildren.addAll([
        const SizedBox(height: 20.0),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_back_ios, size: 30.0),
          label: const Text("Go Back", style: TextStyle(fontSize: 20.0)),
          onPressed: () => Get.back(),
        ),
      ]);
    }

    return Scaffold(
      body: Center(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AnimatedFlutterBrowserLogo(),
                  const SizedBox(width: 80.0),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: commonChildren,
                  ),
                ],
              );
            }

            // Portrait
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AnimatedFlutterBrowserLogo(),
                const SizedBox(height: 80.0),
                ...commonChildren,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGithubButton({
    required BuildContext context,
    required WindowModel windowModel,
    required String repo,
    required String label,
  }) {
    return ElevatedButton.icon(
      icon: const Icon(MaterialCommunityIcons.github, size: 40.0),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.grey.shade300),
      ),
      label: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 16),
          children: [
            const TextSpan(text: "Github: "),
            TextSpan(
              text: repo,
              style: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
      ),
      onPressed: () {
        windowModel.addTab(
          WebViewTab(
            key: GlobalKey(),
            webViewModel: WebViewModel(
              url: WebUri("https://github.com/$repo"),
            ),
          ),
        );
        Get.back();
      },
    );
  }
}