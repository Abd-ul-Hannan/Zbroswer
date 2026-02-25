// screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/qr_scanner_controller.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final QrScannerController controller = Get.put(QrScannerController());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () {
            controller.scannerController.stop();
            Get.back();
          },
        ),
        actions: [
          // Reactive flashlight button using Obx
          Obx(() {
            final bool isOn = controller.torchEnabled.value;
            return IconButton(
              icon: Icon(
                isOn ? Icons.flash_on : Icons.flash_off,
                color: isOn ? Colors.yellow : Colors.white,
                size: 28,
              ),
              onPressed: controller.toggleTorch,
            );
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller.scannerController,
            onDetect: controller.onDetect,
          ),
          // Scan frame with corner brackets
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),
          // Instructions
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align QR code or barcode within the frame',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 50,
        height: 50,
        child: CustomPaint(
          painter: _CornerPainter(),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 15);
    path.lineTo(25, 15);
    path.moveTo(15, 0);
    path.lineTo(15, 25);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}