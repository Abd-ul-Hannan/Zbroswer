import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/DownloadController.dart';

class DownloadManagerScreen extends StatelessWidget {
  static const routeName = '/downloads';

  const DownloadManagerScreen({super.key});

  static void openDownloadScreen(BuildContext context) {
    Get.toNamed(routeName);
  }

  static void handleNotificationClick(BuildContext context) {
    Get.toNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DownloadController());
    return GetBuilder<DownloadController>(
      builder: (controller) {
        return PopScope(
          canPop: true,
          onPopInvoked: (didPop) {
            if (!didPop && controller.isSelectionMode.value) {
              controller.toggleSelectionMode();
            }
          },
          child: DefaultTabController(
            length: 8,
            child: Scaffold(
              appBar: _buildAppBar(controller),
              body: _buildBody(controller),
              floatingActionButton: _buildFloatingActionButtons(controller),
            ),
          ),
        );
      },
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(DownloadController controller) {
    return AppBar(
      title: Obx(() => Text(
            controller.isSelectionMode.value
                ? '${controller.selectedItems.length} Selected'
                : 'Downloads',
          )),
      elevation: 2,
      actions: [
        Obx(() {
          if (controller.isSelectionMode.value) {
            return _buildSelectionModeActions(controller);
          } else {
            return _buildNormalModeActions(controller);
          }
        }),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildTabBar(),
      ),
    );
  }

  Widget _buildTabBar() {
    return const TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(icon: Icon(Icons.all_inclusive), text: 'All'),
        Tab(icon: Icon(Icons.downloading), text: 'Active'),
        Tab(icon: Icon(Icons.check_circle), text: 'Complete'),
        Tab(icon: Icon(Icons.video_library), text: 'Videos'),
        Tab(icon: Icon(Icons.image), text: 'Images'),
        Tab(icon: Icon(Icons.music_note), text: 'Audio'),
        Tab(icon: Icon(Icons.description), text: 'Docs'),
        Tab(icon: Icon(Icons.folder_zip), text: 'APK/ZIP'),
      ],
    );
  }

  Widget _buildSelectionModeActions(DownloadController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: 'Select All',
          onPressed: () => controller.selectAllItems(),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete Selected',
          onPressed: () => _showDeleteSelectedDialog(controller),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNormalModeActions(DownloadController controller) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => _showSettingsDialog(controller),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            // Wait for popup to close
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (!Get.context!.mounted) return;
            
            switch (value) {
              case 'sort_name':
                controller.sortDownloads('name');
                break;
              case 'sort_date':
                controller.sortDownloads('date');
                break;
              case 'sort_size':
                controller.sortDownloads('size');
                break;
              case 'delete_all':
                _showDeleteAllDialog(controller);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sort_name',
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha),
                  SizedBox(width: 8),
                  Text('Sort by Name'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'sort_date',
              child: Row(
                children: [
                  Icon(Icons.access_time),
                  SizedBox(width: 8),
                  Text('Sort by Date'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'sort_size',
              child: Row(
                children: [
                  Icon(Icons.data_usage),
                  SizedBox(width: 8),
                  Text('Sort by Size'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete_all',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete All', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==================== BODY ====================
  Widget _buildBody(DownloadController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return Column(
        children: [
          _buildStatsCard(controller),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _buildFilteredList(controller, 'all'),
                _buildFilteredList(controller, 'downloading'),
                _buildFilteredList(controller, 'complete'),
                _buildFilteredList(controller, 'video'),
                _buildFilteredList(controller, 'image'),
                _buildFilteredList(controller, 'audio'),
                _buildFilteredList(controller, 'document'),
                _buildFilteredList(controller, 'apk'),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ==================== STATS CARD ====================
  Widget _buildStatsCard(DownloadController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                icon: Icons.folder,
                label: 'Total Size',
                value: Obx(() => Text(
                      controller.formatFileSize(controller.downloadSize.value),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    )),
              ),
              _buildStatItem(
                icon: Icons.download,
                label: 'Total Files',
                value: Obx(() => Text(
                      '${controller.downloadItems.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Obx(() => Row(
                  children: [
                    Icon(
                      controller.isWifiConnected.value 
                          ? Icons.wifi 
                          : Icons.signal_cellular_alt,
                      size: 16,
                      color: controller.isWifiConnected.value 
                          ? Colors.green 
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Speed: ${controller.formatFileSize(controller.downloadSpeed.value)}/s',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )),
              ),
              Expanded(
                child: Obx(() {
                  final activeCount = controller.downloadItems
                      .where((item) => item.status == DownloadTaskStatus.running)
                      .length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (controller.settings.value.enableMultiThreading)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Tooltip(
                            message: 'Multi-threading enabled',
                            child: Icon(
                              Icons.multiple_stop,
                              size: 16,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          'Active: $activeCount / ${controller.maxConcurrentDownloads}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(() {
            final chips = <Widget>[];
            
            if (controller.settings.value.wifiOnly) {
              chips.add(_buildChip(
                icon: Icons.wifi,
                label: 'WiFi Only',
                color: Colors.blue,
              ));
            }
            
            if (controller.settings.value.batterySaver) {
              chips.add(_buildChip(
                icon: Icons.battery_saver,
                label: 'Battery Saver',
                color: Colors.orange,
              ));
            }

            if (chips.isEmpty) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: TextStyle(fontSize: 11, color: color),
        ),
        backgroundColor: color.withOpacity(0.1),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required Widget value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            value,
          ],
        ),
      ],
    );
  }

  // ==================== FILTERED LIST ====================
  Widget _buildFilteredList(DownloadController controller, String filter) {
    return Obx(() {
      List<DownloadItem> items;
      if (filter == 'apk') {
        items = controller.getFilteredDownloads('apk') + 
                controller.getFilteredDownloads('archive');
      } else {
        items = controller.getFilteredDownloads(filter);
      }

      if (items.isEmpty) {
        return _buildEmptyState(filter);
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 72,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildDownloadItem(item, controller);
        },
      );
    });
  }

  Widget _buildEmptyState(String filter) {
    String message = 'No downloads yet';
    IconData icon = Icons.download_outlined;
    
    switch (filter) {
      case 'video':
        message = 'No video files';
        icon = Icons.video_library_outlined;
        break;
      case 'image':
        message = 'No image files';
        icon = Icons.image_outlined;
        break;
      case 'audio':
        message = 'No audio files';
        icon = Icons.music_note_outlined;
        break;
      case 'document':
        message = 'No document files';
        icon = Icons.description_outlined;
        break;
      case 'apk':
        message = 'No APK/ZIP files';
        icon = Icons.folder_zip_outlined;
        break;
      case 'downloading':
        message = 'No active downloads';
        icon = Icons.downloading_outlined;
        break;
      case 'complete':
        message = 'No completed downloads';
        icon = Icons.check_circle_outline;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new download',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DOWNLOAD ITEM ====================
  Widget _buildDownloadItem(
    DownloadItem item,
    DownloadController controller,
  ) {
    return Obx(() {
      final isSelected = controller.selectedItems.contains(item.taskId);
      final isSelectionMode = controller.isSelectionMode.value;

      return InkWell(
        onTap: () {
          if (isSelectionMode) {
            controller.toggleItemSelection(item.taskId);
          } else if (item.status == DownloadTaskStatus.complete) {
            _showFileOptionsDialog(item, controller);
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            controller.toggleSelectionMode();
            controller.toggleItemSelection(item.taskId);
          }
        },
        child: Container(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildLeading(item, controller, isSelectionMode, isSelected),
              const SizedBox(width: 16),
              Expanded(
                child: _buildItemContent(item, controller),
              ),
              _buildTrailing(item, controller),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLeading(
    DownloadItem item,
    DownloadController controller,
    bool isSelectionMode,
    bool isSelected,
  ) {
    if (isSelectionMode) {
      return Checkbox(
        value: isSelected,
        onChanged: (_) => controller.toggleItemSelection(item.taskId),
      );
    }

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          controller.getFileTypeIcon(item.fileName),
          if (item.status == DownloadTaskStatus.running)
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: item.progress / 100,
                strokeWidth: 3,
                backgroundColor: Colors.grey[300],
                color: item.isMultiThreaded ? Colors.purple : Colors.blue,
              ),
            ),
          if (item.isMultiThreaded && item.status == DownloadTaskStatus.running)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.multiple_stop,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          if (item.isM3U8)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemContent(DownloadItem item, DownloadController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.selectedQuality != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.selectedQuality!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        _buildStatusText(item, controller),
        if (item.status == DownloadTaskStatus.running)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  controller.getRemainingTimeFormatted(item.taskId) ?? 'Calculating...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (item.isMultiThreaded) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.multiple_stop, size: 12, color: Colors.purple),
                  const SizedBox(width: 2),
                  Text(
                    '${item.chunks?.length ?? 0} threads',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 6),
        if (item.status != DownloadTaskStatus.complete)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress / 100,
              minHeight: 4,
              backgroundColor: Colors.grey[300],
              color: item.isMultiThreaded ? Colors.purple : Colors.blue,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusText(DownloadItem item, DownloadController controller) {
    String statusText;
    Color statusColor;

    switch (item.status) {
      case DownloadTaskStatus.running:
        statusText =
            '${item.progress}% • ${controller.formatFileSize(item.downloadedBytes.toDouble())} / ${controller.formatFileSize(item.fileSize.toDouble())}';
        statusColor = item.isMultiThreaded ? Colors.purple : Colors.blue;
        break;
      case DownloadTaskStatus.complete:
        statusText =
            'Complete • ${controller.formatFileSize(item.fileSize.toDouble())}';
        statusColor = Colors.green;
        break;
      case DownloadTaskStatus.paused:
        statusText =
            'Paused • ${item.progress}% • ${controller.formatFileSize(item.downloadedBytes.toDouble())}';
        statusColor = Colors.orange;
        break;
      case DownloadTaskStatus.failed:
        statusText = 'Failed';
        statusColor = Colors.red;
        break;
      case DownloadTaskStatus.enqueued:
        statusText = 'Waiting in queue...';
        statusColor = Colors.grey;
        break;
      case DownloadTaskStatus.canceled:
        statusText = 'Canceled';
        statusColor = Colors.grey;
        break;
      default:
        statusText = 'Unknown';
        statusColor = Colors.grey;
    }

    return Row(
      children: [
        Flexible(
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (item.isM3U8) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'M3U8',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrailing(DownloadItem item, DownloadController controller) {
    switch (item.status) {
      case DownloadTaskStatus.running:
        return IconButton(
          icon: const Icon(Icons.pause_circle_outline),
          tooltip: 'Pause',
          onPressed: () => controller.pauseDownload(item.taskId),
        );
      
      case DownloadTaskStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: 'Resume',
          onPressed: () => controller.resumeDownload(item.taskId),
        );
      
      case DownloadTaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: () => controller.retryDownload(item.taskId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _showDeleteDialog(item, controller),
            ),
          ],
        );
      
      case DownloadTaskStatus.complete:
        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            // Wait for popup to close
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (!Get.context!.mounted) return;
            
            switch (value) {
              case 'open':
                controller.openFile(item.taskId);
                break;
              case 'share':
                controller.shareFile(item.taskId);
                break;
              case 'rename':
                _showRenameDialog(item, controller);
                break;
              case 'info':
                _showFileInfoDialog(item, controller);
                break;
              case 'delete':
                _showDeleteDialog(item, controller);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new),
                  SizedBox(width: 8),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('File Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        );
      
      case DownloadTaskStatus.canceled:
        return IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () => _showDeleteDialog(item, controller),
        );
      
      case DownloadTaskStatus.enqueued:
        return IconButton(
          icon: const Icon(Icons.cancel_outlined),
          tooltip: 'Cancel',
          onPressed: () => controller.cancelDownload(item.taskId),
        );
      
      default:
        return const SizedBox(width: 48);
    }
  }

  // ==================== FLOATING ACTION BUTTONS ====================
  Widget _buildFloatingActionButtons(DownloadController controller) {
    return Obx(() {
      if (controller.isSelectionMode.value) {
        return FloatingActionButton(
          onPressed: () => controller.toggleSelectionMode(),
          backgroundColor: Colors.red,
          child: const Icon(Icons.close),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () => _showAddDownloadDialog(controller),
            heroTag: 'add_download',
            tooltip: 'Add Download',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            onPressed: () => controller.toggleSelectionMode(),
            heroTag: 'selection_mode',
            backgroundColor: Colors.grey[700],
            tooltip: 'Selection Mode',
            child: const Icon(Icons.checklist, size: 20),
          ),
        ],
      );
    });
  }

  // ==================== DIALOGS ====================
  void _showAddDownloadDialog(DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    final urlController = TextEditingController();
    final fileNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      WillPopScope(
        onWillPop: () async {
          urlController.dispose();
          fileNameController.dispose();
          return true;
        },
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download, color: Colors.blue),
              SizedBox(width: 8),
              Text('Add New Download'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Download URL',
                      hintText: 'https://example.com/file.pdf',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a URL';
                      }
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
                        return 'Please enter a valid URL';
                      }
                      if (!['http', 'https'].contains(uri.scheme)) {
                        return 'Only HTTP and HTTPS URLs are supported';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.url,
                    maxLines: 3,
                    minLines: 1,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: fileNameController,
                    decoration: const InputDecoration(
                      labelText: 'File Name (Optional)',
                      hintText: 'example.pdf',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.text_fields),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supported Features:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        _buildFeatureHint(Icons.multiple_stop, 'Multi-threaded downloads'),
                        _buildFeatureHint(Icons.play_arrow, 'M3U8 video streaming'),
                        _buildFeatureHint(Icons.high_quality, 'Quality selection'),
                        _buildFeatureHint(Icons.pause_circle, 'Pause & Resume'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) {
                  urlController.dispose();
                  fileNameController.dispose();
                  Get.back();
                }
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final url = urlController.text.trim();
                  String fileName = fileNameController.text.trim();

                  if (fileName.isEmpty) {
                    fileName = url.split('/').last;
                  }
                  if (!fileName.contains('.')) {
                    fileName = '$fileName.unknown';
                  }

                  if (Get.isDialogOpen == true) {
                    urlController.dispose();
                    fileNameController.dispose();
                    Get.back();
                  }
                  
                  await Future.delayed(const Duration(milliseconds: 100));
                  controller.enqueueDownloadWithQualitySelection(url, fileName);
                }
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildFeatureHint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blue[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.blue[700]),
          ),
        ],
      ),
    );
  }

  void _showFileOptionsDialog(DownloadItem item, DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: Row(
            children: [
              controller.getFileTypeIcon(item.fileName),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.blue),
                title: const Text('Open'),
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  await Future.delayed(const Duration(milliseconds: 100));
                  controller.openFile(item.taskId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.green),
                title: const Text('Share'),
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  await Future.delayed(const Duration(milliseconds: 100));
                  controller.shareFile(item.taskId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Rename'),
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  await Future.delayed(const Duration(milliseconds: 300));
                  _showRenameDialog(item, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.purple),
                title: const Text('File Info'),
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  await Future.delayed(const Duration(milliseconds: 300));
                  _showFileInfoDialog(item, controller);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  await Future.delayed(const Duration(milliseconds: 300));
                  _showDeleteDialog(item, controller);
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  void _showRenameDialog(DownloadItem item, DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    final nameController = TextEditingController(text: item.fileName);

    Get.dialog(
      WillPopScope(
        onWillPop: () async {
          nameController.dispose();
          return true;
        },
        child: AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'New Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) {
                  nameController.dispose();
                  Get.back();
                }
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  if (Get.isDialogOpen == true) {
                    nameController.dispose();
                    Get.back();
                  }
                  await Future.delayed(const Duration(milliseconds: 100));
                  controller.renameFile(item.taskId, nameController.text.trim());
                }
              },
              child: const Text('Rename'),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  void _showFileInfoDialog(DownloadItem item, DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    final info = controller.getFileInfo(item.taskId);

    Get.dialog(
      AlertDialog(
        title: const Text('File Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Name', info['name'] ?? 'Unknown'),
              _buildInfoRow('Size', info['size'] ?? 'Unknown'),
              _buildInfoRow('Type', info['type'] ?? 'Unknown'),
              _buildInfoRow('Status', info['status'] ?? 'Unknown'),
              _buildInfoRow('Multi-threaded', info['isMultiThreaded']?.toString() ?? 'false'),
              _buildInfoRow('M3U8', info['isM3U8']?.toString() ?? 'false'),
              _buildInfoRow('Path', info['path'] ?? 'Unknown'),
              _buildInfoRow('Downloaded', info['downloadDate'] ?? 'Unknown'),
              const SizedBox(height: 8),
              const Text(
                'URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                info['url'] ?? 'Unknown',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Get.isDialogOpen == true) Get.back();
            },
            child: const Text('Close'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    Get.dialog(
      Obx(() => WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: const Text('Download Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Max Parallel Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: controller.settings.value.maxParallelDownloads.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${controller.settings.value.maxParallelDownloads}',
                  onChanged: (value) {
                    controller.updateSettings(maxParallelDownloads: value.toInt());
                  },
                ),
                
                const Divider(),
                
                const Text('Multi-threading', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                SwitchListTile(
                  title: const Text('Enable Multi-threading'),
                  subtitle: const Text('Faster downloads using parallel threads'),
                  value: controller.settings.value.enableMultiThreading,
                  onChanged: (value) {
                    controller.updateSettings(enableMultiThreading: value);
                  },
                ),
                if (controller.settings.value.enableMultiThreading) ...[
                  const Text('Thread Count', style: TextStyle(fontSize: 12)),
                  Slider(
                    value: controller.settings.value.threadCount.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    label: '${controller.settings.value.threadCount} threads',
                    onChanged: (value) {
                      controller.updateSettings(threadCount: value.toInt());
                    },
                  ),
                ],
                
                const Divider(),
                
                const Text('Video Downloads', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                SwitchListTile(
                  title: const Text('Auto-detect M3U8'),
                  subtitle: const Text('Automatically detect and download streaming videos'),
                  value: controller.settings.value.autoDetectM3U8,
                  onChanged: (value) {
                    controller.updateSettings(autoDetectM3U8: value);
                  },
                ),
                
                const Divider(),
                
                SwitchListTile(
                  title: const Text('Auto Resume'),
                  subtitle: const Text('Resume downloads when network reconnects'),
                  value: controller.settings.value.autoResume,
                  onChanged: (value) {
                    controller.updateSettings(autoResume: value);
                  },
                ),
                SwitchListTile(
                  title: const Text('WiFi Only'),
                  subtitle: const Text('Download only on WiFi connection'),
                  value: controller.settings.value.wifiOnly,
                  onChanged: (value) {
                    controller.updateSettings(wifiOnly: value);
                  },
                ),
                
                const Divider(),
                
                SwitchListTile(
                  title: const Text('Show Notifications'),
                  subtitle: const Text('Display download progress notifications'),
                  value: controller.settings.value.showNotifications,
                  onChanged: (value) {
                    controller.updateSettings(showNotifications: value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Battery Saver'),
                  subtitle: const Text('Reduce downloads when battery is low'),
                  value: controller.settings.value.batterySaver,
                  onChanged: (value) {
                    controller.updateSettings(batterySaver: value);
                  },
                ),
                
                const Divider(),
                
                const Text('Auto Retry Count', style: TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: controller.settings.value.autoRetryCount.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '${controller.settings.value.autoRetryCount}',
                  onChanged: (value) {
                    controller.updateSettings(autoRetryCount: value.toInt());
                  },
                ),
                
                const Divider(),
                
                const Text('Speed Limit (KB/s)', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('0 = Unlimited', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Slider(
                  value: controller.settings.value.speedLimitKBps.toDouble(),
                  min: 0,
                  max: 10000,
                  divisions: 100,
                  label: controller.settings.value.speedLimitKBps == 0 
                      ? 'Unlimited' 
                      : '${controller.settings.value.speedLimitKBps} KB/s',
                  onChanged: (value) {
                    controller.updateSettings(speedLimitKBps: value.toInt());
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) Get.back();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      )),
      barrierDismissible: true,
    );
  }

  void _showDeleteDialog(DownloadItem item, DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: const Text('Delete Download'),
          content: Text(
            'Are you sure you want to delete "${item.fileName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) Get.back();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (Get.isDialogOpen == true) Get.back();
                await Future.delayed(const Duration(milliseconds: 200));
                controller.deleteDownload(item.taskId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  void _showDeleteSelectedDialog(DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: const Text('Delete Selected'),
          content: Text(
            'Delete ${controller.selectedItems.length} selected download(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) Get.back();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (Get.isDialogOpen == true) Get.back();
                await Future.delayed(const Duration(milliseconds: 200));
                controller.deleteSelectedItems();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  void _showDeleteAllDialog(DownloadController controller) {
    if (Get.isDialogOpen == true) return;
    
    Get.dialog(
      WillPopScope(
        onWillPop: () async => true,
        child: AlertDialog(
          title: const Text('Delete All Downloads'),
          content: const Text(
            'Are you sure you want to delete ALL downloads? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) Get.back();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (Get.isDialogOpen == true) Get.back();
                await Future.delayed(const Duration(milliseconds: 200));
                controller.deleteAllDownloads();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }
}
