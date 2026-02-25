import 'package:flutter/material.dart';
import 'dart:io';

class ImageViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;

  const ImageViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(fileName),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(filePath),
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Unable to load image',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
