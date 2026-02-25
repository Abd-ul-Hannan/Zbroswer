import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class TabViewerController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxDouble pageOffset = 0.0.obs;
  
  Timer? _timer;
  int _tabCount = 0;
  bool _isInitialized = false;

  @override
  void onInit() {
    super.onInit();
    debugPrint('TabViewerController initialized');
  }

  void initialize(int tabCount, int initialIndex) {
    if (_isInitialized && _tabCount == tabCount) return;
    
    _tabCount = tabCount;
    currentIndex.value = initialIndex.clamp(0, max(0, tabCount - 1));
    pageOffset.value = currentIndex.value.toDouble();
    _isInitialized = true;
    debugPrint('TabViewerController: Initialized with $tabCount tabs, starting at index $initialIndex');
  }

  void resetInitialization() {
    _isInitialized = false;
  }

  void updatePageOffset(double offset) {
    pageOffset.value = offset.clamp(0.0, max(0.0, _tabCount - 1).toDouble());
  }

  void changeTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    currentIndex.value = index;
    pageOffset.value = index.toDouble();
  }

  void animateToTab(int index) {
    if (index < 0 || index >= _tabCount) return;
    
    final target = index.toDouble();
    final start = pageOffset.value;
    final distance = target - start;
    
    _timer?.cancel();
    
    const duration = 300; // milliseconds
    const frameTime = 16; // ~60fps
    final steps = duration / frameTime;
    var currentStep = 0;
    
    _timer = Timer.periodic(const Duration(milliseconds: frameTime), (timer) {
      currentStep++;
      final progress = currentStep / steps;
      
      if (progress >= 1.0) {
        pageOffset.value = target;
        currentIndex.value = index;
        timer.cancel();
        return;
      }
      
      // Ease-out animation
      final easeProgress = 1 - pow(1 - progress, 3);
      pageOffset.value = start + (distance * easeProgress);
    });
  }

  void cancelTimer() {
    _timer?.cancel();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _isInitialized = false;
    debugPrint('TabViewerController disposed');
    super.onClose();
  }
}