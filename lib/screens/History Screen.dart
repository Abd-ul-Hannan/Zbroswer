import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'package:zbrowser/database/HistoryDatabase.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import '../controllers/History Controller.dart';
import 'package:zbrowser/database/state_manager.dart';
import 'package:zbrowser/tools/custom_image.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely create/load controller (auto-loads via onInit)
    final controller = Get.isRegistered<HistoryController>() ? Get.find<HistoryController>() : Get.put(HistoryController());

    // Safely get current tab's WebViewController
    final windowModel = Get.find<WindowModel>();
    final currentTab = windowModel.getCurrentTab();
    final webViewController = currentTab?.webViewModel.webViewController;

    return WillPopScope(
      onWillPop: () async {
        StateManager.saveState('/', null);
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Browser History'),
        actions: [
            Obx(() => controller.selectedItems.isNotEmpty
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: controller.deleteSelectedItems,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: controller.clearSelection,
                    ),
                  ],
                )
              : const SizedBox.shrink()),
          PopupMenuButton(
            itemBuilder: (_) => [
              PopupMenuItem(
                child: const Text('Clear All History'),
                onTap: controller.clearAllHistory,
              ),
            ],
          ),
        ],
      ),
          body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.history.isEmpty) {
          return const Center(child: Text('No history yet'));
        }

                return ListView.builder(
          itemCount: controller.history.length,
          itemBuilder: (context, index) {
            final item = controller.history[index];
            final int id = item['id'];
            final bool isSelected = controller.selectedItems.contains(id);

            final faviconUrl = item['favicon'] != null
                ? WebUri(item['favicon'])
                : WebUri("${item['url'].split('/').take(3).join('/')}/favicon.ico");

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.blue.withOpacity(0.1),
              leading: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : CustomImage(
                      url: faviconUrl,
                      maxWidth: 30.0,
                      height: 30.0,
                    ),
              title: Text(
                item['title'] ?? 'No Title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item['url'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () async {
                  await HistoryDatabase.instance.deleteHistory(id);
                  await controller.loadHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item removed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              onTap: () {
                if (controller.selectedItems.isNotEmpty) {
                  controller.toggleSelection(id);
                } else {
                  Get.back(); // Close history screen first
                  // Create new tab with the selected URL
                  final windowModel = Get.find<WindowModel>();
                  final newWebViewModel = WebViewModel(
                    url: WebUri(item['url']),
                    title: item['title'] ?? 'Loading...',
                  );
                  final newTab = WebViewTab(
                    key: GlobalKey(),
                    webViewModel: newWebViewModel,
                  );
                  windowModel.addTab(newTab);
                }
              },
              onLongPress: () => controller.toggleSelection(id),
            );
          },
        );
      }),
    ),
    );
  }
}