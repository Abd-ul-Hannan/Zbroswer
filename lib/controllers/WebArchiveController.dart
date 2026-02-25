import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/web_archive_model.dart';

class WebArchiveController extends GetxController {
  final RxSet<WebArchiveModel> selectedArchives = <WebArchiveModel>{}.obs;
  final RxBool isSelectionMode = false.obs;

  // Lazy initialization of BrowserModel
  BrowserModel? get _browserModel {
    try {
      return Get.find<BrowserModel>();
    } catch (e) {
      debugPrint('BrowserModel not found: $e');
      return null;
    }
  }

  void toggleSelection(WebArchiveModel archive) {
    if (selectedArchives.contains(archive)) {
      selectedArchives.remove(archive);
    } else {
      selectedArchives.add(archive);
      isSelectionMode.value = true;
    }

    // Exit selection mode if no items selected
    if (selectedArchives.isEmpty) {
      isSelectionMode.value = false;
    }
  }

  void startSelectionMode() {
    isSelectionMode.value = true;
  }

  void cancelSelection() {
    isSelectionMode.value = false;
    selectedArchives.clear();
  }

  void selectAll(List<WebArchiveModel> allArchives) {
    selectedArchives.assignAll(allArchives);
    isSelectionMode.value = true;
  }

  Future<void> deleteSelected() async {
    if (selectedArchives.isEmpty) return;

    final browserModel = _browserModel;
    if (browserModel == null) {
      _showError('Browser model not available');
      cancelSelection();
      return;
    }

    final count = selectedArchives.length;
    final archivesToDelete = selectedArchives.toList();

    try {
      // Delete all selected archives
      for (var archive in archivesToDelete) {
        browserModel.removeWebArchive(archive);
      }

      await browserModel.save();
      cancelSelection();

      _showSuccess(
        'Deleted',
        '$count web archive${count > 1 ? 's' : ''} removed',
      );
    } catch (e) {
      debugPrint('Error deleting archives: $e');
      _showError('Failed to delete archives');
    }
  }

  Future<void> deleteSingle(WebArchiveModel archive) async {
    final browserModel = _browserModel;
    if (browserModel == null) {
      _showError('Browser model not available');
      return;
    }

    try {
      browserModel.removeWebArchive(archive);
      await browserModel.save();

      _showSuccess('Removed', 'Web archive deleted');
    } catch (e) {
      debugPrint('Error deleting archive: $e');
      _showError('Failed to delete archive');
    }
  }

  void _showSuccess(String title, String message) {
    if (Get.isSnackbarOpen == true) return;
    
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.green.withOpacity(0.8),
      colorText: Colors.white,
    );
  }

  void _showError(String message) {
    if (Get.isSnackbarOpen == true) return;
    
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
    );
  }

  @override
  void onClose() {
    selectedArchives.clear();
    super.onClose();
  }
}