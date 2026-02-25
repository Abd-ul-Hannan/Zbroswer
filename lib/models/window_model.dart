import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/WebViewTabController.dart';
import 'package:zbrowser/main.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:zbrowser/database/state_manager.dart';

import '../utils/util.dart';

class WindowModel extends GetxController {
  final String _id;
  final RxString _name = ''.obs;
  final Rx<DateTime> _updatedTime;
  final DateTime _createdTime;
  final RxList<WebViewTab> _webViewTabs = <WebViewTab>[].obs;
  final RxInt _currentTabIndex = (-1).obs;
  late WebViewModel _currentWebViewModel;
  final RxBool _shouldSave = false.obs;
  final RxBool _showTabScroller = false.obs;

  bool get showTabScroller => _showTabScroller.value;
  set showTabScroller(bool value) => _showTabScroller.value = value;

  bool get shouldSave => _shouldSave.value;
  set shouldSave(bool value) {
    _shouldSave.value = value;
    if (value) {
      saveInfo();
    } else {
      removeInfo();
    }
  }

  DateTime get createdTime => _createdTime;
  DateTime get updatedTime => _updatedTime.value;

  WindowModel({
    String? id,
    String? name,
    bool? shouldSave,
    DateTime? updatedTime,
    DateTime? createdTime,
  })  : _id = id ?? 'window_${const Uuid().v4()}',
        _createdTime = createdTime ?? DateTime.now(),
        _updatedTime = Rx<DateTime>(updatedTime ?? DateTime.now()) {
    _name.value = name ?? '';
    _shouldSave.value = Util.isMobile() ? true : (shouldSave ?? false);
    _currentWebViewModel = WebViewModel();
    _currentTabIndex.value = -1; // Ensure no tab is selected initially
  }

  String get id => _id;

  UnmodifiableListView<WebViewTab> get webViewTabs =>
      UnmodifiableListView(_webViewTabs);

  String get name => _name.value;
  set name(String value) => _name.value = value;

  void addTab(WebViewTab webViewTab) {
  try {
    final url = webViewTab.webViewModel.url;
    debugPrint('WindowModel: Adding tab with URL: $url');
    
    if (webViewTab.webViewModel.needsToCompleteInitialLoad) {
      webViewTab.webViewModel.needsToCompleteInitialLoad = false;
    }
    
    final tag = 'webview_tab_${webViewTab.webViewModel.hashCode}';
    
    if (!Get.isRegistered<WebViewTabController>(tag: tag)) {
      Get.put(
        WebViewTabController(webViewModel: webViewTab.webViewModel),
        tag: tag,
        permanent: false,
      );
      debugPrint('WindowModel: Created controller with tag: $tag');
    }

    _webViewTabs.add(webViewTab);
    _currentTabIndex.value = _webViewTabs.length - 1;
    webViewTab.webViewModel.tabIndex = _currentTabIndex.value;
    webViewTab.webViewModel.lastOpenedTime = DateTime.now();

    _currentWebViewModel.updateWithValue(webViewTab.webViewModel);

    debugPrint('WindowModel: Tab added successfully. Total tabs: ${_webViewTabs.length}, Current index: ${_currentTabIndex.value}');

    if (Get.isRegistered<WebViewModel>()) {
      try {
        final globalWebViewModel = Get.find<WebViewModel>();
        globalWebViewModel.updateWithValue(webViewTab.webViewModel);
      } catch (e) {
        debugPrint('Error updating global WebViewModel: $e');
      }
    }
    
    // CRITICAL: Save state immediately after adding tab
    try {
      final currentUrl = url?.toString();
      final currentRoute = Get.currentRoute;
      StateManager.saveState(currentRoute, currentUrl, tabIndex: _currentTabIndex.value);
      debugPrint('💾 Saved new tab state - URL: $currentUrl');
    } catch (e) {
      debugPrint('Error saving state after addTab: $e');
    }
    
    // Save to database
    saveInfo();
  } catch (e) {
    debugPrint('Error adding tab: $e');
    Get.snackbar(
      'Error',
      'Failed to create new tab',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }
}

void closeTab(int index) {
  if (index < 0 || index >= _webViewTabs.length) return;

  final webViewTab = _webViewTabs[index];
  final tag = 'webview_tab_${webViewTab.webViewModel.hashCode}';

  try {
    if (Get.isRegistered<WebViewTabController>(tag: tag)) {
      Get.delete<WebViewTabController>(tag: tag, force: true);
    }

    _webViewTabs.removeAt(index);
    InAppWebViewController.disposeKeepAlive(webViewTab.webViewModel.keepAlive);

    if (Util.isMobile() || _currentTabIndex.value >= _webViewTabs.length) {
      _currentTabIndex.value = _webViewTabs.length - 1;
    }

    for (int i = index; i < _webViewTabs.length; i++) {
      _webViewTabs[i].webViewModel.tabIndex = i;
    }

    if (_currentTabIndex.value >= 0) {
      final currentTab = _webViewTabs[_currentTabIndex.value];
      currentTab.webViewModel.lastOpenedTime = DateTime.now();
      _currentWebViewModel.updateWithValue(currentTab.webViewModel);
      
      // Save state after closing tab
      try {
        final currentUrl = currentTab.webViewModel.url?.toString();
        final currentRoute = Get.currentRoute;
        StateManager.saveState(currentRoute, currentUrl, tabIndex: _currentTabIndex.value);
        debugPrint('💾 Saved state after tab close - URL: $currentUrl');
      } catch (e) {
        debugPrint('Error saving state after closeTab: $e');
      }
    } else {
      _currentWebViewModel.updateWithValue(WebViewModel());
      
      // Clear state when no tabs left
      try {
        StateManager.clearState();
        debugPrint('💾 Cleared state - no tabs remaining');
      } catch (e) {
        debugPrint('Error clearing state: $e');
      }
    }
    
    // Save to database
    saveInfo();
  } catch (e) {
    debugPrint('Error closing tab: $e');
  }
}
void showTab(int index) {
  if (index < 0 || index >= _webViewTabs.length) return;

  if (_currentTabIndex.value != index) {
    _currentTabIndex.value = index;
    final webViewModel = _webViewTabs[_currentTabIndex.value].webViewModel;
    webViewModel.lastOpenedTime = DateTime.now();
    _currentWebViewModel.updateWithValue(webViewModel);

    // Update global WebViewModel safely
    try {
      if (Get.isRegistered<WebViewModel>()) {
        final globalWebViewModel = Get.find<WebViewModel>();
        globalWebViewModel.updateWithValue(webViewModel);
      }
    } catch (e) {
      debugPrint('Error updating global WebViewModel: $e');
    }
    
    // CRITICAL: Save current state immediately to SharedPreferences
    try {
      final currentUrl = webViewModel.url?.toString();
      final currentRoute = Get.currentRoute;
      StateManager.saveState(currentRoute, currentUrl, tabIndex: index);
      debugPrint('💾 Saved tab switch state - Index: $index, URL: $currentUrl');
    } catch (e) {
      debugPrint('Error saving state: $e');
    }
    
    // Trigger UI update
    update();
  }
  
  // Save to database to ensure latest state is persisted
  saveInfo();
}

  void addTabs(List<WebViewTab> tabs) {
    _webViewTabs.addAll(tabs);
    update();
  }

  void closeAllTabs() {
    debugPrint('Closing all tabs. Current count: ${_webViewTabs.length}');
    
    for (final webViewTab in _webViewTabs) {
      final tag = 'webview_tab_${webViewTab.webViewModel.hashCode}';
      if (Get.isRegistered<WebViewTabController>(tag: tag)) {
        Get.delete<WebViewTabController>(tag: tag, force: true);
      }
      InAppWebViewController.disposeKeepAlive(
        webViewTab.webViewModel.keepAlive,
      );
    }
    _webViewTabs.clear();
    _currentTabIndex.value = -1;
    _currentWebViewModel.updateWithValue(WebViewModel());
    
    debugPrint('All tabs closed. Tab count: ${_webViewTabs.length}, Current index: ${_currentTabIndex.value}');
  }

  int getCurrentTabIndex() => _currentTabIndex.value;

  WebViewTab? getCurrentTab() {
    return _currentTabIndex.value >= 0 
        ? _webViewTabs[_currentTabIndex.value] 
        : null;
  }

  void setCurrentWebViewModel(WebViewModel webViewModel) {
    _currentWebViewModel = webViewModel;
  }

  DateTime _lastTrySave = DateTime.now();
  Timer? _timerSave;

  Future<void> saveInfo() async {
    _timerSave?.cancel();

    if (!_shouldSave.value) return;

    if (DateTime.now().difference(_lastTrySave) >=
        const Duration(milliseconds: 400)) {
      _lastTrySave = DateTime.now();
      await flushInfo();
    } else {
      _lastTrySave = DateTime.now();
      _timerSave = Timer(const Duration(milliseconds: 500), () {
        saveInfo();
      });
    }
  }

  Future<void> removeInfo() async {
    try {
      final count = await db?.rawDelete('DELETE FROM windows WHERE id = ?', [id]);
      if ((count == null || count == 0) && kDebugMode) {
        debugPrint("Cannot delete window $id");
      }
    } catch (e) {
      debugPrint('Error removing window info: $e');
    }
  }

  Future<void> flushInfo() async {
    if (!_shouldSave.value) return;

    try {
      _updatedTime.value = DateTime.now();
      final window = await db?.rawQuery('SELECT * FROM windows WHERE id = ?', [id]);
      
      int? count;
      if (window == null || window.isEmpty) {
        count = await db?.rawInsert(
          'INSERT INTO windows(id, json) VALUES(?, ?)',
          [id, json.encode(toJson())],
        );
      } else {
        count = await db?.rawUpdate(
          'UPDATE windows SET json = ? WHERE id = ?',
          [json.encode(toJson()), id],
        );
      }

      if ((count == null || count == 0) && kDebugMode) {
        debugPrint("Cannot insert/update window $id");
      } else {
        debugPrint("✅ Window state saved successfully. Tabs: ${_webViewTabs.length}");
      }
    } catch (e) {
      debugPrint('Error flushing window info: $e');
    }
  }

  Future<void> restore() async {
    try {
      await restoreInfo();
    } catch (e) {
      debugPrint('Error restoring window: $e');
    }
  }

  Future<void> restoreInfo() async {
    try {
      debugPrint('═══════════════════════════════════');
      debugPrint('📂 Starting WindowModel restoration');
      
      List<Map<String, Object?>>? windows;

      // Restore the most recent window state
      windows = await db?.rawQuery(
        'SELECT * FROM windows ORDER BY id DESC LIMIT 1'
      );

      if (windows == null || windows.isEmpty) {
        debugPrint('⚠️ No saved windows found - starting clean');
        closeAllTabs();
        debugPrint('═══════════════════════════════════');
        return;
      }

      final w = windows[0];
      final source = w['json'] as String;
      debugPrint('📄 Found saved window data');
      
      final browserData = json.decode(source);

      _shouldSave.value = browserData["shouldSave"] ?? false;

      closeAllTabs();

      List<Map<String, dynamic>> webViewTabList =
          browserData["webViewTabs"]?.cast<Map<String, dynamic>>() ?? [];
      
      debugPrint('📊 Found ${webViewTabList.length} saved tabs');
      
      // Filter out invalid tabs
      final originalCount = webViewTabList.length;
      webViewTabList = webViewTabList.where((tabData) {
        final isValid = tabData != null && 
               tabData.isNotEmpty && 
               tabData['url'] != null && 
               tabData['url'].toString().isNotEmpty &&
               tabData['url'].toString() != 'about:blank';
        
        if (!isValid) {
          debugPrint('⚠️ Filtered out invalid tab: ${tabData?['url']}');
        }
        return isValid;
      }).toList();
      
      if (originalCount != webViewTabList.length) {
        debugPrint('🔍 Filtered: ${originalCount - webViewTabList.length} invalid tabs removed');
      }
      
      if (webViewTabList.isNotEmpty) {
        List<WebViewTab> webViewTabs = [];
        
        for (var tabData in webViewTabList) {
          try {
            final webViewModel = WebViewModel.fromMap(tabData);
            if (webViewModel != null && webViewModel.url != null) {
              debugPrint('✅ Restoring tab: ${webViewModel.url}');
              webViewTabs.add(WebViewTab(
                key: GlobalKey(),
                webViewModel: webViewModel,
              ));
            } else {
              debugPrint('⚠️ Failed to create WebViewModel from: ${tabData['url']}');
            }
          } catch (e) {
            debugPrint('❌ Error creating tab: $e');
          }
        }
        
        if (webViewTabs.isNotEmpty) {
          // Sort by tabIndex
          webViewTabs.sort(
            (a, b) => (a.webViewModel.tabIndex ?? 0).compareTo(b.webViewModel.tabIndex ?? 0),
          );

          addTabs(webViewTabs);

          // IMPORTANT: Don't set current tab here - let Browser._initializeBrowser() handle it
          // This allows SharedPreferences to override the database-saved current tab
          int savedCurrentTabIndex = browserData["currentTabIndex"] ?? (_webViewTabs.length - 1);
          savedCurrentTabIndex = savedCurrentTabIndex.clamp(0, _webViewTabs.length - 1);
          
          debugPrint('💾 Database saved current tab index: $savedCurrentTabIndex');
          debugPrint('⏸️ NOT auto-switching - waiting for Browser to apply SharedPreferences state');
          
          // Just set the index without triggering showTab
          _currentTabIndex.value = savedCurrentTabIndex;
          
        } else {
          debugPrint('⚠️ No valid WebViewTab objects created');
        }
      } else {
        debugPrint('⚠️ No valid tabs to restore');
      }


      debugPrint('═══════════════════════════════════');
      debugPrint('✅ WindowModel restoration complete');
      debugPrint('   Total tabs: ${_webViewTabs.length}');
      debugPrint('   Current index: ${_currentTabIndex.value}');
      debugPrint('═══════════════════════════════════');
      
    } catch (e, stack) {
      debugPrint('❌ Error restoring window: $e\n$stack');
      closeAllTabs();
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "id": _id,
      "name": _name.value,
      "webViewTabs": _webViewTabs.map((e) => e.webViewModel.toMap()).toList(),
      "currentTabIndex": _currentTabIndex.value,
      "currentWebViewModel": _currentWebViewModel.toMap(),
      "shouldSave": _shouldSave.value,
      "updatedTime": _updatedTime.value.toIso8601String(),
      "createdTime": _createdTime.toIso8601String(),
    };
  }

  static WindowModel? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    return WindowModel(
      id: map["id"],
      name: map["name"],
      shouldSave: map["shouldSave"],
      updatedTime: map["updatedTime"] != null ? DateTime.tryParse(map["updatedTime"]) : null,
      createdTime: map["createdTime"] != null ? DateTime.tryParse(map["createdTime"]) : null,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => toMap().toString();

  @override
  void onClose() {
    _timerSave?.cancel();
    closeAllTabs();
    super.onClose();
  }
}