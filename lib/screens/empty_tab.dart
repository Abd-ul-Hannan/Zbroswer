// empty_tab.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/qr_scanner_controller.dart';
import 'package:zbrowser/screens/qr_scanner_screen.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../models/browser_model.dart';
import '../models/webview_model.dart';
import '../models/window_model.dart';
import '../database/ShortcutDatabase.dart';
import '../models/shortcut_model.dart';
import '../controllers/SearchHistoryController.dart';

// ===================== CONTROLLER =====================
class EmptyTabController extends GetxController {
  final TextEditingController textController = TextEditingController();

  final SpeechToText speechToText = SpeechToText();
  final ImagePicker picker = ImagePicker();

  final isSpeechEnabled = false.obs;
  final isListening = false.obs;
  final isProcessingImage = false.obs;
  final shortcuts = <ShortcutModel>[].obs;
  final showSearchHistory = false.obs;

  BrowserModel? _browserModel;
  WindowModel? _windowModel;
  SearchHistoryController? _searchHistoryController;

  BrowserModel get browserModel => _browserModel ?? Get.find<BrowserModel>();
  WindowModel get windowModel => _windowModel ?? Get.find<WindowModel>();
  SearchHistoryController get searchHistoryController => 
    _searchHistoryController ?? Get.find<SearchHistoryController>();

  @override
  void onInit() {
    super.onInit();
    _initializeModels();
    _initSpeech();
    loadShortcuts();
    
    textController.addListener(() {
      showSearchHistory.value = textController.text.isEmpty;
    });
  }

  void _initializeModels() {
    try {
      _browserModel = Get.find<BrowserModel>();
      _windowModel = Get.find<WindowModel>();
      _searchHistoryController = Get.put(SearchHistoryController());
    } catch (e) {
      debugPrint('Models not found, will retry on demand: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      isSpeechEnabled.value = await speechToText.initialize(
        onError: (error) => _handleSpeechError(error.errorMsg),
        onStatus: (status) => _handleSpeechStatus(status),
      );
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _showErrorSnackBar('Failed to initialize speech recognition');
    }
  }

  void _handleSpeechError(String error) {
    debugPrint('Speech error: $error');
    String message = 'Speech recognition error occurred';
    if (error.contains('permission')) {
      message = 'Microphone permission required';
    }
    if (error.contains('network')) {
      message = 'Network error in speech recognition';
    }

    _showErrorSnackBar(message);
    isListening.value = false;
  }

  void _handleSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      isListening.value = false;
    }
  }

  Future<void> startListening() async {
    if (!isSpeechEnabled.value) {
      _showErrorSnackBar('Speech recognition not available');
      return;
    }

    try {
      await speechToText.listen(
        onResult: (result) {
          textController.text = result.recognizedWords;
          if (result.finalResult) {
            openNewTab(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.search,
      );
      isListening.value = true;
    } catch (e) {
      debugPrint('Start listening error: $e');
      _showErrorSnackBar('Failed to start speech recognition');
      isListening.value = false;
    }
  }

  Future<void> stopListening() async {
    try {
      await speechToText.stop();
    } catch (e) {
      debugPrint('Stop listening error: $e');
    } finally {
      isListening.value = false;
    }
  }

  void openLiveQrScanner() {
    Get.to(() => const QrScannerScreen())?.then((result) {
      if (result != null && result.isNotEmpty) {
        HapticFeedback.mediumImpact();
        showDetectedCodeDialog(result);
      }
    });
  }

  void showImageSourceDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Search or Scan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              subtitle: const Text('Text recognition or QR/barcode'),
              onTap: () {
                Get.back();
                processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Text recognition or QR/barcode'),
              onTap: () {
                Get.back();
                processImage(ImageSource.gallery);
              },
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.green),
              title: const Text('Scan QR/Barcode with Camera'),
              subtitle: const Text('Live scanning with flashlight'),
              onTap: () {
                Get.back();
                openLiveQrScanner();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> processImage(ImageSource source) async {
    if (isProcessingImage.value) return;

    isProcessingImage.value = true;

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile == null) {
        isProcessingImage.value = false;
        return;
      }

      // OCR - Text Recognition
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (recognizedText.text.isNotEmpty) {
        _showTextRecognitionDialog(pickedFile.path, recognizedText.text);
      }

      // QR/Barcode from same image
      await scanQrFromImage(pickedFile.path);
    } catch (e) {
      debugPrint('Process image error: $e');
      _showErrorSnackBar('Failed to process image');
    } finally {
      isProcessingImage.value = false;
    }
  }

  void _showTextRecognitionDialog(String imagePath, String recognizedText) {
    Get.dialog(
      AlertDialog(
        title: const Text('Text Recognized'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.file(File(imagePath)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Found Text:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(recognizedText),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  textController.text = recognizedText;
                  openNewTab(recognizedText);
                },
                icon: const Icon(Icons.search),
                label: const Text('Search This Text'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  searchByImage(imagePath);
                },
                icon: const Icon(Icons.image_search),
                label: const Text('Search Similar Images'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> scanQrFromImage(String path) async {
    MobileScannerController? scanner;
    try {
      scanner = MobileScannerController();
      final capture = await scanner.analyzeImage(path);

      if (capture?.barcodes.isNotEmpty == true) {
        final code = capture!.barcodes.first.rawValue ?? '';
        if (code.isNotEmpty) {
          showDetectedCodeDialog(code);
        }
      }
    } catch (e) {
      debugPrint('QR scan from image error: $e');
      // Silent fail
    } finally {
      await scanner?.dispose();
    }
  }

  void showDetectedCodeDialog(String code) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('QR/Barcode Detected'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              Get.back();
              Get.snackbar(
                'Success',
                'Copied to clipboard',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () {
              Share.share(code);
              Get.back();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open / Search'),
            onPressed: () {
              Get.back();
              openNewTab(code);
            },
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void searchByImage(String imagePath) {
    final searchUrl = WebUri('https://www.google.co.uk/imghp?hl=en&ogbl');
    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(),
        webViewModel: WebViewModel(url: searchUrl),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      duration: const Duration(seconds: 3),
    );
  }

  void openNewTab(String value) {
    if (value.trim().isEmpty) return;

    try {
      final settings = browserModel.getSettings();
      final trimmedValue = value.trim();
      WebUri url;

      // Better URL validation and construction
      if (_isValidUrl(trimmedValue)) {
        url = trimmedValue.startsWith('http') 
            ? WebUri(trimmedValue)
            : WebUri('https://$trimmedValue');
      } else {
        // Use search engine for non-URL queries
        final searchQuery = Uri.encodeComponent(trimmedValue);
        url = WebUri('${settings.searchEngine.searchUrl}$searchQuery');
        searchHistoryController.addSearch(trimmedValue);
      }

      debugPrint('EmptyTab: Creating new tab with URL: $url');

      // Create WebViewModel with proper initialization
      final webViewModel = WebViewModel(
        url: url,
        needsToCompleteInitialLoad: false, // Allow immediate loading
      );

      // Create and add the new tab
      final newTab = WebViewTab(
        key: GlobalKey(),
        webViewModel: webViewModel,
      );

      windowModel.addTab(newTab);
      
      // Clear the search field after successful tab creation
      textController.clear();
      
    } catch (e) {
      debugPrint('Open new tab error: $e');
      _showErrorSnackBar('Failed to open new tab: ${e.toString()}');
    }
  }

  bool _isValidUrl(String value) {
    // Check if it's a valid URL pattern
    final urlPattern = RegExp(
      r'^(https?:\/\/)?' // protocol
      r'((([a-z\d]([a-z\d-]*[a-z\d])*)\.)+[a-z]{2,}|' // domain name
      r'((\d{1,3}\.){3}\d{1,3}))' // OR ip (v4) address
      r'(\:\d+)?(\/[-a-z\d%_.~+]*)*' // port and path
      r'(\?[;&a-z\d%_.~+=-]*)?' // query string
      r'(\#[-a-z\d_]*)?\$', // fragment locator
      caseSensitive: false,
    );
    
    return urlPattern.hasMatch(value) || 
           value.contains('.') && !value.contains(' ');
  }

  Future<void> loadShortcuts() async {
    try {
      final data = await ShortcutDatabase.instance.getShortcuts();
      shortcuts.assignAll(data);
    } catch (e) {
      debugPrint('Error loading shortcuts: $e');
    }
  }

  Future<void> addShortcut(String title, String url) async {
    try {
      // Ensure URL has protocol
      String normalizedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        normalizedUrl = 'https://$url';
      }
      
      // Extract domain for favicon
      final uri = Uri.parse(normalizedUrl);
      final domain = uri.host;
      
      final shortcut = ShortcutModel(
        title: title,
        url: normalizedUrl,
        favicon: 'https://www.google.com/s2/favicons?domain=$domain&sz=32',
      );
      await ShortcutDatabase.instance.insertShortcut(shortcut);
      await loadShortcuts();
    } catch (e) {
      debugPrint('Error adding shortcut: $e');
    }
  }

  Future<void> deleteShortcut(int index) async {
    try {
      if (index < 0 || index >= shortcuts.length) {
        debugPrint('Invalid index: $index');
        return;
      }
      
      final shortcut = shortcuts[index];
      debugPrint('Attempting to delete shortcut at index $index: ${shortcut.title}');
      
      final allShortcuts = await ShortcutDatabase.instance.getShortcuts();
      final dbShortcut = allShortcuts.firstWhereOrNull(
        (s) => s.title == shortcut.title && s.url == shortcut.url
      );
      
      if (dbShortcut != null && dbShortcut.id != null) {
        await ShortcutDatabase.instance.deleteShortcut(dbShortcut.id!);
        debugPrint('Deleted shortcut with id: ${dbShortcut.id}');
      }
      
      await loadShortcuts();
    } catch (e) {
      debugPrint('Error deleting shortcut: $e');
    }
  }

  void showAddShortcutDialog() {
    final titleController = TextEditingController();
    final urlController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Add Shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., GitHub',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'e.g., https://github.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && urlController.text.isNotEmpty) {
                addShortcut(titleController.text, urlController.text);
                Get.back();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  void onClose() {
    textController.dispose();
    
    // Stop listening if active
    if (isListening.value) {
      stopListening();
    }
    
    super.onClose();
  }
}

// ===================== VIEW =====================
class EmptyTab extends StatelessWidget {
  const EmptyTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Use unique tag for this instance
    final String controllerTag = 'empty_tab_${DateTime.now().millisecondsSinceEpoch}';
    
    final controller = Get.put(
      EmptyTabController(),
      tag: controllerTag,
    );

    return WillPopScope(
      onWillPop: () async {
        if (controller.isListening.value) {
          await controller.stopListening();
          Get.snackbar(
            'Cancelled',
            'Voice search cancelled',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
          );
          return false;
        }
        
        // Clean up controller
        Get.delete<EmptyTabController>(tag: controllerTag);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Search Engine Logo
                  GetBuilder<BrowserModel>(
                    builder: (bm) {
                      final settings = bm.getSettings();
                      return Image(
                        image: AssetImage(settings.searchEngine.assetIcon),
                        height: 120,
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Search Bar
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 584),
                    child: Container(
                      height: 65,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(32),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 20),
                          const Icon(Icons.search, color: Colors.black45, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                controller.showSearchHistory.value = 
                                  hasFocus && controller.textController.text.isEmpty;
                              },
                              child: TextField(
                                controller: controller.textController,
                                onSubmitted: controller.openNewTab,
                                textInputAction: TextInputAction.search,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Search Anything",
                                  hintStyle: TextStyle(
                                    color: Colors.black45,
                                    fontSize: 16,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          // Buttons Row
                          SizedBox(
                            width: 150,
                            child: Row(
                              children: [
                                Obx(
                                  () => IconButton(
                                    icon: Icon(
                                      Icons.mic,
                                      color: controller.isListening.value
                                          ? Colors.blue
                                          : Colors.black45,
                                      size: 26,
                                    ),
                                    tooltip: controller.isListening.value
                                        ? 'Stop listening'
                                        : 'Search by voice',
                                    onPressed: controller.isListening.value
                                        ? controller.stopListening
                                        : controller.startListening,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.black54,
                                    size: 26,
                                  ),
                                  tooltip: 'Scan QR/Barcode',
                                  onPressed: controller.openLiveQrScanner,
                                ),
                                Obx(
                                  () => IconButton(
                                    icon: Icon(
                                      Icons.camera_alt,
                                      color: controller.isProcessingImage.value
                                          ? Colors.blue
                                          : Colors.black45,
                                      size: 26,
                                    ),
                                    tooltip: 'Search by image or text',
                                    onPressed: controller.isProcessingImage.value
                                        ? null
                                        : controller.showImageSourceDialog,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),

                  // Listening / Processing Indicator
                  Obx(
                    () {
                      if (controller.isListening.value) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                "Listening...",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (controller.isProcessingImage.value) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                "Processing image...",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  const SizedBox(height: 24),

                  // Search History
                  Obx(() {
                    if (!controller.showSearchHistory.value) {
                      return const SizedBox(height: 24);
                    }
                    
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 584),
                      child: Obx(() {
                        final history = controller.searchHistoryController.searchHistory;
                        if (history.isEmpty) return const SizedBox(height: 24);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Recent Searches',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => controller.searchHistoryController.clearHistory(),
                                      child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: history.length > 5 ? 5 : history.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final query = history[index];
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.history, size: 20, color: Colors.grey),
                                    title: Text(
                                      query,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => controller.searchHistoryController.deleteSearch(query),
                                    ),
                                    onTap: () {
                                      controller.textController.text = query;
                                      controller.openNewTab(query);
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  }),

                  // Quick Access Section
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 584),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Quick Access',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: controller.showAddShortcutDialog,
                              tooltip: 'Add shortcut',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Obx(
                          () => controller.shortcuts.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.bookmark_border,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No shortcuts yet',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add your favorite websites for quick access',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: controller.shortcuts.length,
                                  itemBuilder: (context, index) {
                                    final shortcut = controller.shortcuts[index];
                                    return GestureDetector(
                                      onTap: () => controller.openNewTab(shortcut.url),
                                      onLongPress: () => _showShortcutOptions(controller, index),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey[200]!),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: Image.network(
                                                  shortcut.favicon ?? 'https://www.google.com/s2/favicons?domain=google.com&sz=32',
                                                  width: 20,
                                                  height: 20,
                                                  fit: BoxFit.cover,
                                                  cacheWidth: 32,
                                                  cacheHeight: 32,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.language,
                                                      color: Colors.blue[600],
                                                      size: 20,
                                                    );
                                                  },
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                    if (loadingProgress == null) return child;
                                                    return Icon(
                                                      Icons.language,
                                                      color: Colors.blue[600],
                                                      size: 20,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              shortcut.title,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShortcutOptions(EmptyTabController controller, int index) {
    Get.dialog(
      AlertDialog(
        title: Text(controller.shortcuts[index].title),
        content: Text('What would you like to do with this shortcut?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteShortcut(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.openNewTab(controller.shortcuts[index].url);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}