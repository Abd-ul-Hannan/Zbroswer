// controllers/qr_scanner_controller.dart
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/services.dart';

class QrScannerController extends GetxController {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.all],
    autoStart: true,
  );

  final scannedCode = RxnString();

  // Manually create an observable for torch state
  final torchEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();

    // Sync initial state
    torchEnabled.value = scannerController.torchEnabled;

    // Start camera
    scannerController.start();
  }

  void onDetect(BarcodeCapture capture) {
    final String? code = capture.barcodes.firstOrNull?.rawValue;

    if (code != null && code.isNotEmpty && scannedCode.value == null) {
      scannedCode.value = code;
      HapticFeedback.mediumImpact();
      scannerController.stop();
      Get.back(result: code); // Return result safely
    }
  }

  /// Toggle torch and update observable
  void toggleTorch() {
    scannerController.toggleTorch();
    // Update our observable immediately
    torchEnabled.value = scannerController.torchEnabled;
  }

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }
}