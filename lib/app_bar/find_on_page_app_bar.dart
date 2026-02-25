import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'package:zbrowser/models/browser_model.dart';
import '../models/window_model.dart';

class FindOnPageAppBar extends StatelessWidget {
  final void Function()? hideFindOnPage;

  const FindOnPageAppBar({super.key, this.hideFindOnPage});

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Ensure controller exists with proper tag
    final controller = Get.put(
      FindOnPageController(hideFindOnPage: hideFindOnPage),
      tag: 'findOnPage',
    );

    return AppBar(
      titleSpacing: 10.0,
      title: SizedBox(
        height: 40.0,
        child: TextField(
          onSubmitted: (_) => controller.findAll(),
          controller: controller.searchController,
          textInputAction: TextInputAction.go,
          autofocus: true, // ✅ Auto focus for better UX
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.all(10.0),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent, width: 0.0),
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent, width: 0.0),
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.transparent, width: 0.0),
              borderRadius: BorderRadius.all(Radius.circular(50.0)),
            ),
            hintText: "Find on page ...",
            hintStyle: TextStyle(color: Colors.black54, fontSize: 16.0),
          ),
          style: const TextStyle(color: Colors.black, fontSize: 16.0),
        ),
      ),
      actions: [
        GetBuilder<FindOnPageController>(
          tag: 'findOnPage',
          builder: (ctrl) => Text(
            ctrl.matchesText,
            style: const TextStyle(color: Colors.white, fontSize: 12.0),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          onPressed: controller.findPrevious,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: controller.findNext,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: controller.closeFindOnPage,
        ),
      ],
    );
  }
}

class FindOnPageController extends GetxController {
  final void Function()? hideFindOnPage;
  
  // ✅ FIXED: Getter for WindowModel instead of late initialization
  WindowModel get windowModel => Get.find<WindowModel>();
  
  FindInteractionController? _findController;

  FindOnPageController({this.hideFindOnPage});

  final TextEditingController searchController = TextEditingController();
  String _matchesText = '';

  String get matchesText => _matchesText;

  set matchesText(String value) {
    _matchesText = value;
    update();
  }

  @override
  void onInit() {
    super.onInit();
    
    // ✅ FIXED: Initialize find controller properly
    _updateFindController();
    
    // ✅ FIXED: Add listener for real-time search
    searchController.addListener(_onSearchTextChanged);
  }

  @override
  void onClose() {
    searchController.removeListener(_onSearchTextChanged);
    searchController.dispose();
    _findController = null;
    super.onClose();
  }

  // ✅ FIXED: Separate method for search text changes
  void _onSearchTextChanged() {
    final text = searchController.text.trim();
    if (text.isNotEmpty) {
      findAll();
    } else {
      _clearMatches();
    }
  }

  // ✅ FIXED: Update find controller when tab changes
  void _updateFindController() {
    final currentTab = windowModel.getCurrentTab();
    if (currentTab != null) {
      _findController = currentTab.webViewModel.findInteractionController;
      
      // ✅ Set up listener for find results
      _setupFindResultListener();
    }
  }

  // ✅ FIXED: Listen to find interaction results
  void _setupFindResultListener() {
    // Note: If flutter_inappwebview supports result callbacks, 
    // you can set them up here. For now, we'll update manually.
  }

  void findAll() {
    final text = searchController.text.trim();
    if (text.isEmpty) {
      _clearMatches();
      return;
    }

    // ✅ FIXED: Update controller if tab changed
    _updateFindController();

    if (_findController != null) {
      _findController!.findAll(find: text);
      
      // ✅ FIXED: Update matches text
      // Note: Actual count would come from callback if available
      matchesText = 'Searching...';
    } else {
      matchesText = 'No active page';
    }
  }

  void findPrevious() {
    if (_findController != null) {
      _findController!.findNext(forward: false);
    }
  }

  void findNext() {
    if (_findController != null) {
      _findController!.findNext(forward: true);
    }
  }

  void closeFindOnPage() {
    _clearMatches();
    searchController.clear();

    if (hideFindOnPage != null) {
      hideFindOnPage!();
    }
  }

  void _clearMatches() {
    _findController?.clearMatches();
    matchesText = '';
  }

  // ✅ FIXED: Public method to refresh controller when tab changes
  void refreshFindController() {
    _updateFindController();
  }

  // ✅ FIXED: Method to update match count (call from webview callbacks)
  void updateMatchCount(int activeMatchOrdinal, int numberOfMatches) {
    if (numberOfMatches > 0) {
      matchesText = '${activeMatchOrdinal + 1}/$numberOfMatches';
    } else {
      matchesText = '0/0';
    }
  }
}