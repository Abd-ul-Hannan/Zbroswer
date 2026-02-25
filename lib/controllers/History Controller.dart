import 'package:flutter/material.dart';
import 'package:zbrowser/database/HistoryDatabase.dart';
import 'package:get/get.dart';
import 'dart:async';

class HistoryController extends GetxController {
  // Reactive state — use these in UI with Obx
  final history = <Map<String, dynamic>>[].obs;
  final selectedItems = <int>{}.obs;
  final isLoading = false.obs;
  
  Timer? _refreshTimer;

  // Computed property
  bool get hasSelectedItems => selectedItems.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    loadHistory(); // Auto-load when controller is created
    _startAutoRefresh();
  }
  
  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }
  
  void _startAutoRefresh() {
    // Refresh history every 2 seconds when screen is active
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (Get.currentRoute == '/history') {
        refreshHistory();
      }
    });
  }

  Future<void> loadHistory() async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final data = await HistoryDatabase.instance.getHistory();
      history.assignAll(data);
    } catch (e) {
      debugPrint('Error loading history: $e');
      Get.snackbar('Error', 'Failed to load history');
    } finally {
      isLoading.value = false;
    }
  }
  
  // Method to refresh history without loading indicator
  Future<void> refreshHistory() async {
    try {
      final data = await HistoryDatabase.instance.getHistory();
      history.assignAll(data);
    } catch (e) {
      debugPrint('Error refreshing history: $e');
    }
  }

  void toggleSelection(int id) {
    if (selectedItems.contains(id)) {
      selectedItems.remove(id);
    } else {
      selectedItems.add(id);
    }
  }

  void clearSelection() {
    selectedItems.clear();
  }

  Future<void> deleteSelectedItems() async {
    if (selectedItems.isEmpty) return;

    final toDelete = List<int>.from(selectedItems);
    selectedItems.clear();

    for (var id in toDelete) {
      await HistoryDatabase.instance.deleteHistory(id);
    }

    await loadHistory();
  }

  Future<void> clearAllHistory() async {
    await HistoryDatabase.instance.clearHistory();
    history.clear();
    selectedItems.clear();
  }
}