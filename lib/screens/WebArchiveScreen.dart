import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/WebArchiveController.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/web_archive_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/tools/custom_image.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zbrowser/database/state_manager.dart';

class WebArchivesScreen extends StatelessWidget {
  const WebArchivesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        StateManager.saveState('/', null);
        return true;
      },
      child: const WebArchivesContent(),
    );
  }
}

class WebArchivesContent extends StatelessWidget {
  const WebArchivesContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final archiveController = Get.find<WebArchiveController>();

    return Obx(() {
      final browserModel = Get.find<BrowserModel>();
      final webArchives = browserModel.webArchives;

      return Scaffold(
        appBar: _buildAppBar(archiveController, webArchives),
        body: _buildBody(webArchives, archiveController),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(
    WebArchiveController controller,
    Map<String, WebArchiveModel> webArchives,
  ) {
    return AppBar(
      leading: Obx(() {
        if (controller.isSelectionMode.value) {
          return IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => controller.cancelSelection(),
          );
        }
        return IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        );
      }),
      title: Obx(() {
        if (controller.isSelectionMode.value) {
          final count = controller.selectedArchives.length;
          return Text('$count selected');
        }
        return const Text('Web Archives');
      }),
      actions: [
        Obx(() {
          if (controller.isSelectionMode.value) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => controller.selectAll(
                    webArchives.values.toList(),
                  ),
                  tooltip: 'Select All',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(controller),
                  tooltip: 'Delete Selected',
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildBody(
    Map<String, WebArchiveModel> webArchives,
    WebArchiveController controller,
  ) {
    if (webArchives.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No web archives',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: webArchives.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final entry = webArchives.entries.elementAt(index);
        final webArchive = entry.value;

        return _buildArchiveListTile(
          webArchive,
          controller,
        );
      },
    );
  }

  Widget _buildArchiveListTile(
    WebArchiveModel webArchive,
    WebArchiveController controller,
  ) {
    final path = webArchive.path;
    final url = webArchive.url;

    return Obx(() {
      final isSelectionMode = controller.isSelectionMode.value;
      final isSelected = controller.selectedArchives.contains(webArchive);

      return ListTile(
        leading: _buildLeading(
          isSelectionMode,
          isSelected,
          url,
          controller,
          webArchive,
        ),
        title: Text(
          webArchive.title ?? url?.toString() ?? "Untitled",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          url?.toString() ?? "",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blue.withOpacity(0.1),
        onTap: () => _handleTap(
          isSelectionMode,
          controller,
          webArchive,
          path,
        ),
        onLongPress: () => controller.toggleSelection(webArchive),
        trailing: _buildTrailing(isSelectionMode, controller, webArchive),
      );
    });
  }

  Widget _buildLeading(
    bool isSelectionMode,
    bool isSelected,
    WebUri? url,
    WebArchiveController controller,
    WebArchiveModel webArchive,
  ) {
    if (isSelectionMode) {
      return Checkbox(
        value: isSelected,
        onChanged: (_) => controller.toggleSelection(webArchive),
      );
    }

    return CustomImage(
      url: WebUri("${url?.origin ?? ""}/favicon.ico"),
      maxWidth: 30.0,
      height: 30.0,
    );
  }

  Widget? _buildTrailing(
    bool isSelectionMode,
    WebArchiveController controller,
    WebArchiveModel webArchive,
  ) {
    if (isSelectionMode) return null;

    return IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () => _confirmDeleteSingle(controller, webArchive),
      tooltip: 'Delete',
    );
  }

  void _handleTap(
    bool isSelectionMode,
    WebArchiveController controller,
    WebArchiveModel webArchive,
    String? path,
  ) {
    if (isSelectionMode) {
      controller.toggleSelection(webArchive);
    } else if (path != null) {
      Get.back();
      _openArchiveInNewTab(path);
    }
  }

  void _confirmDelete(WebArchiveController controller) {
    final count = controller.selectedArchives.length;
    
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Archives'),
        content: Text(
          'Are you sure you want to delete $count archive${count > 1 ? 's' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteSelected();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSingle(
    WebArchiveController controller,
    WebArchiveModel webArchive,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Archive'),
        content: Text(
          'Are you sure you want to delete "${webArchive.title ?? 'this archive'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.deleteSingle(webArchive);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openArchiveInNewTab(String path) {
    try {
      final windowModel = Get.find<WindowModel>();
      windowModel.addTab(
        WebViewTab(
          key: GlobalKey(),
          webViewModel: WebViewModel(url: WebUri("file://$path")),
        ),
      );
    } catch (e) {
      debugPrint('Error opening archive: $e');
      Get.snackbar(
        'Error',
        'Failed to open archive',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }
}