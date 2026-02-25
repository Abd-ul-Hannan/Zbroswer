import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zbrowser/controllers/DownloadController.dart';
import 'package:zbrowser/tools/custom_image.dart';
import 'package:zbrowser/screens/webview_tab.dart';

import '../main.dart';
import '../models/browser_model.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import 'package:zbrowser/controllers/DownloadController.dart';

// Controller for Long Press Dialog
class LongPressController extends GetxController {
  final isLinkPreviewReady = false.obs;

  void setLinkPreviewReady(bool value) {
    isLinkPreviewReady.value = value;
  }

  @override
  void onInit() {
    super.onInit();
    isLinkPreviewReady.value = false;
  }

  @override
  void onClose() {
    super.onClose();
  }
}

class LongPressAlertDialog extends StatelessWidget {
  static const List<InAppWebViewHitTestResultType> hitTestResultSupported = [
    InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE,
    InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE,
    InAppWebViewHitTestResultType.IMAGE_TYPE,
  ];

  const LongPressAlertDialog({
    super.key,
    required this.webViewModel,
    required this.hitTestResult,
    this.requestFocusNodeHrefResult,
  });

  final WebViewModel webViewModel;
  final InAppWebViewHitTestResult hitTestResult;
  final RequestFocusNodeHrefResult? requestFocusNodeHrefResult;

  @override
  Widget build(BuildContext context) {
    // Create unique tag for this dialog instance
    final String controllerTag = 
        'long_press_${DateTime.now().millisecondsSinceEpoch}';
    
    // Put controller with unique tag
    final controller = Get.put(
      LongPressController(),
      tag: controllerTag,
    );

    // Get WindowModel - assuming it's registered globally
    final windowModel = Get.find<WindowModel>();

    return WillPopScope(
      onWillPop: () async {
        // Clean up controller when dialog closes
        Get.delete<LongPressController>(tag: controllerTag);
        return true;
      },
      child: AlertDialog(
        contentPadding: const EdgeInsets.all(0.0),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _buildDialogItems(
                controller, 
                windowModel, 
                controllerTag,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDialogItems(
    LongPressController controller,
    WindowModel windowModel,
    String controllerTag,
  ) {
    // Determine the type of content
    String? urlString = hitTestResult.extra ?? 
        requestFocusNodeHrefResult?.url?.toString();

    // Check if it's a video URL
    bool isVideo = _isVideoUrl(urlString);
    
    // Check if it's an image
    bool isImage = hitTestResult.type == InAppWebViewHitTestResultType.IMAGE_TYPE;
    
    // Check if it's a link (not a video)
    bool isLink = !isVideo && !isImage && (
        hitTestResult.type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
        hitTestResult.type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE ||
        (requestFocusNodeHrefResult?.url != null &&
            requestFocusNodeHrefResult!.url.toString().isNotEmpty));

    // VIDEO LONG PRESS
    if (isVideo) {
      return [
        _buildVideoTile(),
        const Divider(height: 1),
        _buildOpenNewTab(windowModel, controllerTag),
        _buildOpenNewIncognitoTab(windowModel, controllerTag),
        _buildDownloadVideo(controllerTag),
        _buildShareLink(controllerTag),
      ];
    }
    
    // IMAGE LONG PRESS
    else if (isImage) {
      return [
        _buildImageTile(),
        const Divider(height: 1),
        _buildDownloadImage(controllerTag),
        _buildShareImage(controllerTag),
      ];
    }
    
    // LINK LONG PRESS
    else if (isLink) {
      return [
        _buildLinkTile(),
        const Divider(height: 1),
        _buildOpenNewTab(windowModel, controllerTag),
        _buildOpenNewIncognitoTab(windowModel, controllerTag),
        _buildShareLink(controllerTag),
      ];
    }

    // EMPTY/TEXT - No dialog should be shown
    return [];
  }

  bool _isVideoUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    // Common video file extensions
    final videoExtensions = [
      '.mp4', '.webm', '.ogg', '.mov', '.avi', 
      '.mkv', '.flv', '.wmv', '.m4v', '.3gp',
      '.m3u8', '.ts', '.mpd' // Added streaming formats
    ];
    
    // Common video hosting patterns
    final videoPatterns = [
      'youtube.com/watch',
      'youtu.be/',
      'vimeo.com/',
      'dailymotion.com/',
      'twitch.tv/',
      'video',
      'stream',
    ];
    
    String lowerUrl = url.toLowerCase();
    
    // Check extensions
    if (videoExtensions.any((ext) => lowerUrl.contains(ext))) {
      return true;
    }
    
    // Check patterns
    if (videoPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return true;
    }
    
    return false;
  }

  bool _isImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    final imageExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.bmp', 
      '.webp', '.svg', '.ico'
    ];
    
    String lowerUrl = url.toLowerCase();
    return imageExtensions.any((ext) => lowerUrl.endsWith(ext));
  }

  // ==================== LINK WIDGETS ====================
  Widget _buildLinkTile() {
    var url = requestFocusNodeHrefResult?.url ?? Uri.parse("about:blank");
    var faviconUrl = Uri.parse("${url.origin}/favicon.ico");

    var title = requestFocusNodeHrefResult?.title ?? "";
    if (title.isEmpty) title = "Link";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          CustomImage(
            url: requestFocusNodeHrefResult?.src != null
                ? Uri.parse(requestFocusNodeHrefResult!.src!)
                : faviconUrl,
            maxWidth: 40.0,
            height: 40.0,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  requestFocusNodeHrefResult?.url?.toString() ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== VIDEO WIDGETS ====================
  Widget _buildVideoTile() {
    var url = requestFocusNodeHrefResult?.url ?? 
        Uri.parse(hitTestResult.extra ?? "about:blank");

    String title = "Video";
    if (requestFocusNodeHrefResult?.title != null && 
        requestFocusNodeHrefResult!.title!.isNotEmpty) {
      title = requestFocusNodeHrefResult!.title!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(
              Icons.play_circle_outline,
              color: Colors.white,
              size: 28.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  url.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadVideo(String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.download, color: Colors.blue),
      title: const Text("Download video"),
      onTap: () async {
        String? urlString = hitTestResult.extra ?? 
            requestFocusNodeHrefResult?.url?.toString();
            
        if (urlString == null || urlString.isEmpty) {
          Get.delete<LongPressController>(tag: controllerTag);
          Get.back();
          return;
        }

        // Close dialog first
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();

        try {
          // Get download controller
          final downloadController = Get.find<DownloadController>();
          
          // Extract filename from URL
          var uri = Uri.parse(urlString);
          String fileName = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          
          // Ensure it has video extension
          if (!fileName.contains('.')) {
            fileName = '$fileName.mp4';
          }

          // Enqueue download with quality selection if supported
          await downloadController.enqueueDownloadWithQualitySelection(
            urlString,
            fileName,
          );

          Get.snackbar(
            'Download Started',
            fileName,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.download, color: Colors.white),
          );
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to start download: $e',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.error_outline, color: Colors.white),
          );
        }
      },
    );
  }

  // ==================== IMAGE WIDGETS ====================
  Widget _buildImageTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: CustomImage(
              url: Uri.parse(hitTestResult.extra!),
              maxWidth: 60.0,
              height: 60.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Image",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  hitTestResult.extra ?? "",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadImage(String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.download, color: Colors.blue),
      title: const Text("Download image"),
      onTap: () async {
        String? url = hitTestResult.extra;
        if (url == null || url.isEmpty) {
          Get.delete<LongPressController>(tag: controllerTag);
          Get.back();
          return;
        }

        // Close dialog first
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();

        try {
          // Get download controller
          final downloadController = Get.find<DownloadController>();
          
          var uri = Uri.parse(url);
          String fileName = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

          // Ensure it has image extension
          if (!fileName.contains('.')) {
            fileName = '$fileName.jpg';
          }

          // Enqueue download
          await downloadController.enqueueDownload(url, fileName);

          Get.snackbar(
            'Download Started',
            fileName,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
            icon: const Icon(Icons.download, color: Colors.white),
          );
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to start download: $e',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.error_outline, color: Colors.white),
          );
        }
      },
    );
  }

  Widget _buildShareImage(String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.share, color: Colors.blue),
      title: const Text("Share image"),
      onTap: () {
        if (hitTestResult.extra != null) {
          Share.share(hitTestResult.extra!);
        }
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();
      },
    );
  }

  // ==================== COMMON ACTIONS ====================
  Widget _buildOpenNewTab(WindowModel windowModel, String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.open_in_new, color: Colors.blue),
      title: const Text("Open in new tab"),
      onTap: () {
        var url = requestFocusNodeHrefResult?.url ?? 
            (hitTestResult.extra != null ? WebUri(hitTestResult.extra!) : null);
        
        if (url != null) {
          windowModel.addTab(
            WebViewTab(
              key: GlobalKey(),
              webViewModel: WebViewModel(url: url),
            ),
          );
        }
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();
      },
    );
  }

  Widget _buildOpenNewIncognitoTab(WindowModel windowModel, String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.lock_outline, color: Colors.blue),
      title: const Text("Open in incognito tab"),
      onTap: () {
        var url = requestFocusNodeHrefResult?.url ?? 
            (hitTestResult.extra != null ? WebUri(hitTestResult.extra!) : null);
        
        if (url != null) {
          windowModel.addTab(
            WebViewTab(
              key: GlobalKey(),
              webViewModel: WebViewModel(
                url: url,
                isIncognitoMode: true,
              ),
            ),
          );
        }
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();
      },
    );
  }

  Widget _buildShareLink(String controllerTag) {
    return ListTile(
      leading: const Icon(Icons.share, color: Colors.blue),
      title: const Text("Share link"),
      onTap: () {
        final shareUrl = requestFocusNodeHrefResult?.url?.toString() ??
            hitTestResult.extra ??
            '';
        if (shareUrl.isNotEmpty) {
          Share.share(shareUrl);
        }
        Get.delete<LongPressController>(tag: controllerTag);
        Get.back();
      },
    );
  }
}