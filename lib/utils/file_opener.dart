import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zbrowser/screens/video_player_screen.dart';
import 'package:zbrowser/screens/image_viewer_screen.dart';
import 'package:zbrowser/screens/pdf_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
class FileOpener {
  static Future<void> openFile(String filePath, String fileName) async {
    final file = File(filePath);
    
    if (!await file.exists()) {
      Get.snackbar(
        'File Not Found',
        'The file does not exist',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final extension = fileName.toLowerCase().split('.').last;

    // Video files
    if (_isVideoFile(extension)) {
      Get.to(() => VideoPlayerScreen(filePath: filePath, fileName: fileName));
      return;
    }

    // Image files
    if (_isImageFile(extension)) {
      Get.to(() => ImageViewerScreen(filePath: filePath, fileName: fileName));
      return;
    }

    // PDF files
    if (extension == 'pdf') {
      Get.to(() => PdfViewerScreen(filePath: filePath, fileName: fileName));
      return;
    }

    // APK files (Android only)
    if (extension == 'apk' && Platform.isAndroid) {
      _installApk(filePath);
      return;
    }

    // iOS specific handling
    if (Platform.isIOS) {
      _openFileIOS(filePath, fileName);
      return;
    }

    // For other files, use system default app
    _openWithSystemApp(filePath);
  }

  static bool _isVideoFile(String extension) {
    return ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', '3gp'].contains(extension);
  }

  static bool _isImageFile(String extension) {
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
  }

  static Future<void> _installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        Get.snackbar(
          'Installation Failed',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to install APK: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  static Future<void> _openFileIOS(String filePath, String fileName) async {
    try {
      // Try using open_file first
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        // Fallback to URL launcher for iOS
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          Get.snackbar(
            'Cannot Open File',
            'No app available to open this file type',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  static Future<void> _openWithSystemApp(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      
      if (result.type != ResultType.done) {
        Get.snackbar(
          'Cannot Open File',
          result.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to open file: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
