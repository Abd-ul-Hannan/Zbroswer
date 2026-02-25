import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/DownloadController.dart';

class FloatingDownloadBubble extends StatelessWidget {
  const FloatingDownloadBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GetBuilder<DownloadController>(
          init: Get.find<DownloadController>(),
          builder: (controller) {
            final activeCount = controller.downloadItems
                .where((item) => item.status == DownloadTaskStatus.running)
                .length;
            
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '$activeCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    controller.formatFileSize(controller.downloadSpeed.value),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}