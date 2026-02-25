import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:zbrowser/utils/javascript_console_result.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import '../models/window_model.dart';

class JavaScriptConsole extends StatelessWidget {
  const JavaScriptConsole({super.key});

  @override
  Widget build(BuildContext context) {
    // GetX Controller ko Get.put se initialize karein agar nahi hai
    final controller = Get.put(JavaScriptConsoleController(), permanent: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Console Results List
        Flexible(
          child: Obx(() {
            final results = controller.webViewModel.value?.javaScriptConsoleResults ?? [];
            return ListView.builder(
              controller: controller.scrollController,
              itemCount: results.length,
              itemBuilder: (context, index) => results[index],
            );
          }),
        ),

        const Divider(),

        // Input + Buttons Row
        SizedBox(
          height: 75.0,
          child: Row(
            children: [
              Flexible(
                child: TextField(
                  expands: true,
                  onSubmitted: (_) => controller.evaluateJavaScript(),
                  controller: controller.searchController,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: "document.querySelector('body') ...",
                    prefixIcon: Icon(Icons.keyboard_arrow_right, color: Colors.blue),
                    border: InputBorder.none,
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: controller.evaluateJavaScript,
              ),

              // History Up/Down Buttons
              Obx(() {
                final viewModel = controller.webViewModel.value;
                if (viewModel == null) {
                  return const SizedBox.shrink();
                }
                
                final history = viewModel.javaScriptConsoleHistory;
                final index = controller.currentHistoryIndex.value;
                final canGoUp = index > 0;
                final canGoDown = index < history.length;
                
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      height: 35.0,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        onPressed: canGoUp ? () => controller.navigateHistory(up: true) : null,
                      ),
                    ),
                    SizedBox(
                      height: 35.0,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: canGoDown ? () => controller.navigateHistory(up: false) : null,
                      ),
                    ),
                  ],
                );
              }),

              // Clear Console
              IconButton(
                icon: const Icon(Icons.cancel),
                onPressed: controller.clearConsole,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class JavaScriptConsoleController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  
  // WebViewModel ko Rx<WebViewModel?> banaya for reactivity
  final Rx<WebViewModel?> webViewModel = Rx<WebViewModel?>(null);
  final currentHistoryIndex = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeWebViewModel();
  }

  void _initializeWebViewModel() {
    WebViewModel? candidate;
    
    try {
      // Pehle WindowModel se current tab try karein
      if (Get.isRegistered<WindowModel>()) {
        final windowModel = Get.find<WindowModel>();
        candidate = windowModel.getCurrentTab()?.webViewModel;
      }
    } catch (e) {
      debugPrint('WindowModel se WebViewModel nahi mila: $e');
    }

    // Agar nahi mila to directly WebViewModel dhundo
    if (candidate == null) {
      try {
        if (Get.isRegistered<WebViewModel>()) {
          candidate = Get.find<WebViewModel>();
        }
      } catch (e) {
        debugPrint('WebViewModel registered nahi hai: $e');
      }
    }

    // Set the webViewModel
    webViewModel.value = candidate;

    // History index set karein
    if (candidate != null) {
      currentHistoryIndex.value = candidate.javaScriptConsoleHistory.length;
    }
  }

  @override
  void onClose() {
    searchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void evaluateJavaScript() async {
    final source = searchController.text.trim();
    if (source.isEmpty) return;

    final viewModel = webViewModel.value;
    if (viewModel == null) {
      Get.snackbar(
        'Error',
        'WebView not initialized',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final currentController = viewModel.webViewController;
    if (currentController == null) {
      Get.snackbar(
        'Error',
        'WebViewController not available',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Add to history if new
    if (viewModel.javaScriptConsoleHistory.isEmpty ||
        viewModel.javaScriptConsoleHistory.last != source) {
      viewModel.addJavaScriptConsoleHistory(source);
      currentHistoryIndex.value = viewModel.javaScriptConsoleHistory.length;
    }

    try {
      final result = await currentController.evaluateJavascript(source: source);
      viewModel.addJavaScriptConsoleResults(
        JavaScriptConsoleResult(data: result.toString()),
      );
    } catch (e) {
      viewModel.addJavaScriptConsoleResults(
        JavaScriptConsoleResult(data: 'Error: $e'),
      );
    }

    _scrollToBottom();
  }

  void navigateHistory({required bool up}) {
    final viewModel = webViewModel.value;
    if (viewModel == null) return;

    final history = viewModel.javaScriptConsoleHistory;

    if (up) {
      currentHistoryIndex.value = (currentHistoryIndex.value - 1).clamp(0, history.length);
    } else {
      if (currentHistoryIndex.value >= history.length) {
        currentHistoryIndex.value = history.length;
        searchController.text = "";
        return;
      }
      currentHistoryIndex.value++;
    }

    if (currentHistoryIndex.value < history.length) {
      searchController.text = history[currentHistoryIndex.value];
    } else {
      searchController.text = "";
    }
  }

  void clearConsole() {
    final viewModel = webViewModel.value;
    if (viewModel == null) return;
    
    viewModel.setJavaScriptConsoleResults([]);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.ease,
        );
      }
    });
  }

  // Helper method to update webViewModel from outside if needed
  void updateWebViewModel(WebViewModel? newViewModel) {
    webViewModel.value = newViewModel;
    if (newViewModel != null) {
      currentHistoryIndex.value = newViewModel.javaScriptConsoleHistory.length;
    }
  }
}