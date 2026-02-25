import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:zbrowser/app_bar/certificates_info_popup.dart';
import 'package:zbrowser/routes/custom_popup_dialog_page_route.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import '../dialogs+action/custom_popup_dialog.dart';

class UrlInfoPopup extends StatelessWidget {
  final CustomPopupDialogPageRoute route;
  final Duration transitionDuration;
  final Function()? onWebViewTabSettingsClicked;

  const UrlInfoPopup({
    super.key,
    required this.route,
    required this.transitionDuration,
    this.onWebViewTabSettingsClicked,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Controller should already be registered from parent
    // We use Get.find with tag instead of conditional registration
    final controller = Get.find<UrlInfoController>(tag: 'urlInfo');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ FIXED: Single GetBuilder for entire URL display
          GetBuilder<WindowModel>(
            builder: (windowModel) {
              final webViewModel = windowModel.getCurrentTab()?.webViewModel;
              
              return GestureDetector(
                onTap: controller.toggleShowFullUrl,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  constraints: const BoxConstraints(maxHeight: 100.0),
                  child: Obx(() {
                    final url = webViewModel?.url;

                    return RichText(
                      maxLines: controller.showFullUrl.value ? null : 2,
                      overflow: controller.showFullUrl.value 
                        ? TextOverflow.clip 
                        : TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black54, 
                          fontSize: 12.5
                        ),
                        children: [
                          TextSpan(
                            text: url?.scheme ?? "",
                            style: TextStyle(
                              color: (webViewModel?.isSecure ?? false) 
                                ? Colors.green 
                                : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: url?.toString() == "about:blank" ? ':' : '://',
                          ),
                          TextSpan(
                            text: url?.host ?? "",
                            style: const TextStyle(color: Colors.black),
                          ),
                          TextSpan(text: url?.path ?? ""),
                          TextSpan(text: url?.query ?? ""),
                        ],
                      ),
                    );
                  }),
                ),
              );
            },
          ),

          // ✅ FIXED: Single GetBuilder for connection status
          GetBuilder<WindowModel>(
            builder: (windowModel) {
              final webViewModel = windowModel.getCurrentTab()?.webViewModel;
              
              final String text1 = (webViewModel?.isSecure ?? false)
                  ? "Your connection is protected"
                  : "Your connection to this website is not protected";

              final String text2 = (webViewModel?.isSecure ?? false)
                  ? "Your sensitive data (e.g. passwords or credit card numbers) remains private when it is sent to this site."
                  : "You should not enter sensitive data on this site (e.g. passwords or credit cards) because they could be intercepted by malicious users.";

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      text1, 
                      style: const TextStyle(fontSize: 16.0)
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12.0, 
                        color: Colors.black87
                      ),
                      children: [
                        TextSpan(text: "$text2 "),
                        TextSpan(
                          text: "Details",
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = controller.showCertificateInfo,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 30.0),

          // WebView Tab Settings Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: controller.goToWebViewTabSettings,
              child: const Text("WebView Tab Settings"),
            ),
          ),
        ],
      ),
    );
  }
}

class UrlInfoController extends GetxController {
  final CustomPopupDialogPageRoute route;
  final Duration transitionDuration;
  final Function()? onWebViewTabSettingsClicked;

  UrlInfoController({
    required this.route,
    required this.transitionDuration,
    this.onWebViewTabSettingsClicked,
  });

  final showFullUrl = false.obs;

  void toggleShowFullUrl() {
    showFullUrl.toggle();
  }

  void showCertificateInfo() {
    if (!(Get.context?.mounted ?? false)) return;
    
    // ✅ FIXED: Close current dialog first
    Get.back();
    
    // ✅ FIXED: Ensure CertificateInfoController is properly created
    Get.dialog(
      const CertificateInfoPopup(),
    ).then((_) {
      // ✅ FIXED: Cleanup certificate controller when dialog closes
      if (Get.isRegistered<CertificateInfoController>()) {
        Get.delete<CertificateInfoController>();
      }
    });
  }

  void goToWebViewTabSettings() {
    if (!(Get.context?.mounted ?? false)) return;
    
    // Close popup
    Get.back();
    
    // Call callback
    if (onWebViewTabSettingsClicked != null) {
      onWebViewTabSettingsClicked!();
    }
  }

  // ✅ FIXED: Proper cleanup
  @override
  void onClose() {
    showFullUrl.close();
    super.onClose();
  }
}