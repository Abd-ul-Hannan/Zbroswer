import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/favorite_model.dart';

class FavoriteController extends GetxController {
  // Observable variables
  final selectedFavorites = <FavoriteModel>{}.obs;
  final isSelectionMode = false.obs;

  // Toggle selection of a favorite
  void toggleSelection(FavoriteModel favorite) {
    if (selectedFavorites.contains(favorite)) {
      selectedFavorites.remove(favorite);
    } else {
      selectedFavorites.add(favorite);
    }

    // If no favorites selected, turn off selection mode
    if (selectedFavorites.isEmpty) {
      isSelectionMode.value = false;
    }
  }

  // Start selection mode
  void startSelectionMode() {
    isSelectionMode.value = true;
  }

  // Cancel selection and clear all
  void cancelSelection() {
    isSelectionMode.value = false;
    selectedFavorites.clear();
  }

  // Delete all selected favorites with confirmation
  void deleteSelected() {
    if (selectedFavorites.isEmpty) return;

    final count = selectedFavorites.length;
    Get.dialog(
      AlertDialog(
        title: Text('Delete $count favorite${count > 1 ? 's' : ''}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              if (!Get.isRegistered<BrowserModel>()) {
                Get.back();
                Get.snackbar('Error', 'BrowserModel not available', snackPosition: SnackPosition.BOTTOM);
                return;
              }

              final browserModel = Get.find<BrowserModel>();
              for (var fav in selectedFavorites.toList()) {
                browserModel.removeFavorite(fav);
              }
              cancelSelection();
              Get.back();
              Get.snackbar(
                'Deleted',
                '$count favorite${count > 1 ? 's' : ''} removed',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}