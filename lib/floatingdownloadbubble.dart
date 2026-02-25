import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay;
import 'package:get/get.dart';

// ==================== IMPORTANT ====================
// This file should be registered as overlay entry point in main.dart
// Add this to main.dart:
// 
// @pragma("vm:entry-point")
// void overlayMain() {
//   runApp(const FloatingDownloadBubble());
// }
// ===================================================

class FloatingDownloadController extends GetxController {
  var activeDownloads = 0.obs;
  var downloadSpeed = '0 KB/s'.obs;
  var totalDownloads = 0.obs;
  var isExpanded = false.obs;
  var lastUpdateTime = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    _listenToMainApp();
  }

  void _listenToMainApp() {
    try {
      overlay.FlutterOverlayWindow.overlayListener.listen((data) {
        if (data != null && data is Map) {
          activeDownloads.value = data['active_downloads'] ?? 0;
          downloadSpeed.value = data['speed'] ?? '0 KB/s';
          totalDownloads.value = data['total_downloads'] ?? 0;
          lastUpdateTime.value = DateTime.now();
          
          debugPrint('📊 Bubble updated: ${activeDownloads.value} active, ${downloadSpeed.value}');
        }
      }, onError: (error) {
        debugPrint('❌ Bubble listener error: $error');
      });
    } catch (e) {
      debugPrint('❌ Error setting up bubble listener: $e');
    }
  }

  void toggleExpanded() {
    isExpanded.toggle();
    debugPrint('🔄 Bubble ${isExpanded.value ? "expanded" : "collapsed"}');
  }

  void closeBubble() {
    try {
      overlay.FlutterOverlayWindow.closeOverlay();
      debugPrint('✅ Bubble closed');
    } catch (e) {
      debugPrint('❌ Error closing bubble: $e');
    }
  }
}

class FloatingDownloadBubble extends StatelessWidget {
  const FloatingDownloadBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FloatingDownloadController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: controller.toggleExpanded,
        onDoubleTap: controller.closeBubble,
        child: Center(
          child: Obx(() => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: controller.isExpanded.value ? 220 : 80,
              height: controller.isExpanded.value ? 140 : 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: controller.activeDownloads.value > 0
                      ? [Colors.blue[700]!, Colors.blue[900]!]
                      : [Colors.grey[700]!, Colors.grey[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  controller.isExpanded.value ? 20 : 40,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: controller.isExpanded.value 
                  ? _buildExpandedView(controller) 
                  : _buildCollapsedView(controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedView(FloatingDownloadController controller) {
    return Obx(() => Stack(
      children: [
        // Main icon
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              controller.activeDownloads.value > 0 
                  ? Icons.downloading 
                  : Icons.download,
              key: ValueKey(controller.activeDownloads.value > 0),
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        
        // Active downloads badge
        if (controller.activeDownloads.value > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '${controller.activeDownloads.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // Progress indicator at bottom
        if (controller.activeDownloads.value > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              child: Container(
                height: 4,
                child: const LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        
        // Pulse animation for active downloads
        if (controller.activeDownloads.value > 0)
          Positioned.fill(
            child: CustomPaint(
              painter: PulsePainter(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
      ],
    ));
  }

  Widget _buildExpandedView(FloatingDownloadController controller) {
    return Obx(() => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    controller.activeDownloads.value > 0 
                        ? Icons.downloading 
                        : Icons.download_done,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Downloads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: controller.closeBubble,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          
          // Stats
          Column(
            children: [
              _buildInfoRow(
                Icons.downloading,
                'Active',
                '${controller.activeDownloads.value}',
                controller.activeDownloads.value > 0 
                    ? Colors.green 
                    : Colors.grey,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.speed,
                'Speed',
                controller.downloadSpeed.value,
                controller.activeDownloads.value > 0 
                    ? Colors.blue 
                    : Colors.grey,
              ),
              const SizedBox(height: 6),
              _buildInfoRow(
                Icons.folder,
                'Total',
                '${controller.totalDownloads.value}',
                Colors.purple,
              ),
            ],
          ),
          
          // Progress bar for active downloads
          if (controller.activeDownloads.value > 0)
            Column(
              children: [
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  'No active downloads',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          
          // Hint text
          Text(
            'Tap to collapse • Double tap to close',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ));
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for pulse animation
class PulsePainter extends CustomPainter {
  final Color color;

  PulsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius - 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}