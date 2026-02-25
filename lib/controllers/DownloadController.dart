import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:get/get.dart';

// ==================== MODELS ====================
class VideoQuality {
  final String quality;
  final String url;
  final int? fileSize;
  final String? format;

  VideoQuality({
    required this.quality,
    required this.url,
    this.fileSize,
    this.format,
  });

  Map<String, dynamic> toJson() => {
    'quality': quality,
    'url': url,
    'fileSize': fileSize,
    'format': format,
  };

  factory VideoQuality.fromJson(Map<String, dynamic> json) => VideoQuality(
    quality: json['quality'],
    url: json['url'],
    fileSize: json['fileSize'],
    format: json['format'],
  );
}

class DownloadChunk {
  final int index;
  final int start;
  final int end;
  final String filePath;
  int downloadedBytes;
  bool isComplete;

  DownloadChunk({
    required this.index,
    required this.start,
    required this.end,
    required this.filePath,
    this.downloadedBytes = 0,
    this.isComplete = false,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'start': start,
    'end': end,
    'filePath': filePath,
    'downloadedBytes': downloadedBytes,
    'isComplete': isComplete,
  };

  factory DownloadChunk.fromJson(Map<String, dynamic> json) => DownloadChunk(
    index: json['index'],
    start: json['start'],
    end: json['end'],
    filePath: json['filePath'],
    downloadedBytes: json['downloadedBytes'] ?? 0,
    isComplete: json['isComplete'] ?? false,
  );
}

class DownloadItem {
  final String taskId;
  final String fileName;
  final String url;
  final String savedDir;
  final DownloadTaskStatus status;
  final int progress;
  final int fileSize;
  final DateTime startTime;
  final int downloadedBytes;
  final String? fileType;
  final DateTime? estimatedCompletionTime;
  final bool isM3U8;
  final bool isMultiThreaded;
  final List<DownloadChunk>? chunks;
  final List<VideoQuality>? availableQualities;
  final String? selectedQuality;

  DownloadItem({
    required this.taskId,
    required this.fileName,
    required this.url,
    required this.savedDir,
    required this.status,
    required this.progress,
    required this.fileSize,
    required this.startTime,
    this.downloadedBytes = 0,
    this.fileType,
    this.estimatedCompletionTime,
    this.isM3U8 = false,
    this.isMultiThreaded = false,
    this.chunks,
    this.availableQualities,
    this.selectedQuality,
  });

  DownloadItem copyWith({
    String? taskId,
    String? fileName,
    String? url,
    String? savedDir,
    DownloadTaskStatus? status,
    int? progress,
    int? fileSize,
    DateTime? startTime,
    int? downloadedBytes,
    String? fileType,
    DateTime? estimatedCompletionTime,
    bool? isM3U8,
    bool? isMultiThreaded,
    List<DownloadChunk>? chunks,
    List<VideoQuality>? availableQualities,
    String? selectedQuality,
  }) {
    return DownloadItem(
      taskId: taskId ?? this.taskId,
      fileName: fileName ?? this.fileName,
      url: url ?? this.url,
      savedDir: savedDir ?? this.savedDir,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileSize: fileSize ?? this.fileSize,
      startTime: startTime ?? this.startTime,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      fileType: fileType ?? this.fileType,
      estimatedCompletionTime: estimatedCompletionTime ?? this.estimatedCompletionTime,
      isM3U8: isM3U8 ?? this.isM3U8,
      isMultiThreaded: isMultiThreaded ?? this.isMultiThreaded,
      chunks: chunks ?? this.chunks,
      availableQualities: availableQualities ?? this.availableQualities,
      selectedQuality: selectedQuality ?? this.selectedQuality,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'fileName': fileName,
      'url': url,
      'savedDir': savedDir,
      'status': status.index,
      'progress': progress,
      'fileSize': fileSize,
      'startTime': startTime.toIso8601String(),
      'downloadedBytes': downloadedBytes,
      'fileType': fileType,
      'estimatedCompletionTime': estimatedCompletionTime?.toIso8601String(),
      'isM3U8': isM3U8,
      'isMultiThreaded': isMultiThreaded,
      'chunks': chunks?.map((c) => c.toJson()).toList(),
      'availableQualities': availableQualities?.map((q) => q.toJson()).toList(),
      'selectedQuality': selectedQuality,
    };
  }

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      taskId: json['taskId'],
      fileName: json['fileName'],
      url: json['url'],
      savedDir: json['savedDir'],
      status: DownloadTaskStatus.values[json['status']],
      progress: json['progress'],
      fileSize: json['fileSize'],
      startTime: DateTime.parse(json['startTime']),
      downloadedBytes: json['downloadedBytes'] ?? 0,
      fileType: json['fileType'],
      estimatedCompletionTime: json['estimatedCompletionTime'] != null 
          ? DateTime.parse(json['estimatedCompletionTime'])
          : null,
      isM3U8: json['isM3U8'] ?? false,
      isMultiThreaded: json['isMultiThreaded'] ?? false,
      chunks: json['chunks'] != null 
          ? (json['chunks'] as List).map((c) => DownloadChunk.fromJson(c)).toList()
          : null,
      availableQualities: json['availableQualities'] != null 
          ? (json['availableQualities'] as List).map((q) => VideoQuality.fromJson(q)).toList()
          : null,
      selectedQuality: json['selectedQuality'],
    );
  }
}

enum DownloadTaskStatus {
  undefined,
  enqueued,
  running,
  complete,
  failed,
  canceled,
  paused,
}

class DownloadSettings {
  int maxParallelDownloads;
  String downloadFolder;
  bool autoResume;
  int autoRetryCount;
  bool showNotifications;
  bool wifiOnly;
  int speedLimitKBps;
  bool batterySaver;
  bool foregroundService;
  bool enableMultiThreading;
  int threadCount;
  bool autoDetectM3U8;

  DownloadSettings({
    this.maxParallelDownloads = 3,
    this.downloadFolder = '',
    this.autoResume = true,
    this.autoRetryCount = 3,
    this.showNotifications = true,
    this.wifiOnly = false,
    this.speedLimitKBps = 0,
    this.batterySaver = false,
    this.foregroundService = true,
    this.enableMultiThreading = true,
    this.threadCount = 4,
    this.autoDetectM3U8 = true,
  });

  Map<String, dynamic> toJson() => {
    'maxParallelDownloads': maxParallelDownloads,
    'downloadFolder': downloadFolder,
    'autoResume': autoResume,
    'autoRetryCount': autoRetryCount,
    'showNotifications': showNotifications,
    'wifiOnly': wifiOnly,
    'speedLimitKBps': speedLimitKBps,
    'batterySaver': batterySaver,
    'foregroundService': foregroundService,
    'enableMultiThreading': enableMultiThreading,
    'threadCount': threadCount,
    'autoDetectM3U8': autoDetectM3U8,
  };

  factory DownloadSettings.fromJson(Map<String, dynamic> json) => DownloadSettings(
    maxParallelDownloads: json['maxParallelDownloads'] ?? 3,
    downloadFolder: json['downloadFolder'] ?? '',
    autoResume: json['autoResume'] ?? true,
    autoRetryCount: json['autoRetryCount'] ?? 3,
    showNotifications: json['showNotifications'] ?? true,
    wifiOnly: json['wifiOnly'] ?? false,
    speedLimitKBps: json['speedLimitKBps'] ?? 0,
    batterySaver: json['batterySaver'] ?? false,
    foregroundService: json['foregroundService'] ?? true,
    enableMultiThreading: json['enableMultiThreading'] ?? true,
    threadCount: json['threadCount'] ?? 4,
    autoDetectM3U8: json['autoDetectM3U8'] ?? true,
  );
}

class SpeedTracker {
  int lastBytes = 0;
  DateTime lastUpdate = DateTime.now();
  final List<double> _speedHistory = [];
  static const int maxHistorySize = 10;

  double updateSpeed(int currentBytes) {
    final now = DateTime.now();
    final duration = now.difference(lastUpdate).inSeconds;
    if (duration == 0) return getAverageSpeed();

    final speed = (currentBytes - lastBytes) / duration.toDouble();
    lastBytes = currentBytes;
    lastUpdate = now;

    _speedHistory.add(speed);
    if (_speedHistory.length > maxHistorySize) {
      _speedHistory.removeAt(0);
    }

    return getAverageSpeed();
  }

  double getAverageSpeed() {
    if (_speedHistory.isEmpty) return 0;
    final validSpeeds = _speedHistory.where((speed) => speed.isFinite && speed >= 0).toList();
    if (validSpeeds.isEmpty) return 0;
    return validSpeeds.reduce((a, b) => a + b) / validSpeeds.length;
  }

  Duration? getRemainingTime(int remainingBytes) {
    final avgSpeed = getAverageSpeed();
    if (avgSpeed <= 0) return null;
    return Duration(seconds: (remainingBytes / avgSpeed).round());
  }
}

// ==================== DOWNLOAD CONTROLLER ====================
class DownloadController extends GetxController {
  Timer? _batteryTimer;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<BatteryState>? _batterySubscription;

  int _notificationIdCounter = 1000;
  final Map<String, int> _taskNotificationIds = {};

  final downloadItems = <DownloadItem>[].obs;
  final isSelectionMode = false.obs;
  final selectedItems = <String>{}.obs;
  final downloadSize = 0.0.obs;
  final downloadSpeed = 0.0.obs;
  final isLoading = true.obs;
  final downloadQueue = <String>[].obs;
  final activeDownloads = <String, http.Client>{}.obs;
  final _activeSpeedTrackers = <String, SpeedTracker>{};
  final _notificationUpdateTimers = <String, DateTime>{};
  final _retryCounters = <String, int>{};
  final _manuallyPausedItems = <String>{}.obs;
  
  // CRITICAL: Track operations in progress to prevent race conditions
  final _pauseInProgress = <String>{}.obs;
  final _deleteInProgress = <String>{}.obs;
  final _renameInProgress = <String>{}.obs;
  
  // FIX: Prevent queue from processing paused items
  bool _isProcessingQueue = false;
  
  // CRITICAL FIX: Track completed downloads to prevent auto-hiding
  final _completedDownloads = <String>{}.obs;
  
  final settings = DownloadSettings().obs;
  final isWifiConnected = false.obs;
  final batteryLevel = 100.obs;
  final isBatterySaverActive = false.obs;

  String _downloadPath = '';
  Timer? _speedTimer;
  Timer? _queueTimer;
  Timer? _persistenceTimer;

  String get downloadPath => _downloadPath;
  int get maxConcurrentDownloads => settings.value.maxParallelDownloads;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
      _initializeDownloadManager();
      _startSpeedTimer();
      _startQueueTimer();
      _startPersistenceTimer();
      _initializeConnectivityMonitoring();
      _initializeBatteryMonitoring();
    });
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _queueTimer?.cancel();
    _persistenceTimer?.cancel();
    _batteryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _batterySubscription?.cancel();
    for (var client in activeDownloads.values) {
      client.close();
    }
    _saveDownloads();
    super.dispose();
  }

  // ==================== INITIALIZATION ====================
  void _initializeNotifications() {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);
    
    _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          Get.toNamed('/downloads');
        }
      },
    );
  }

  Future<void> _initializeDownloadManager() async {
    try {
      await loadSettings();
      await _initializeDownloadPath();
      await _requestStoragePermission();
      await _loadPersistedDownloads();
      await _loadStorageInfo();
    } catch (e) {
      debugPrint('Error initializing download manager: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _initializeDownloadPath() async {
    if (kIsWeb) {
      _downloadPath = '';
    } else if (Platform.isAndroid) {
      if (Platform.version.contains('API 30') || Platform.version.contains('API 31') || Platform.version.contains('API 32') || Platform.version.contains('API 33')) {
        final dir = await getExternalStorageDirectory();
        _downloadPath = settings.value.downloadFolder.isNotEmpty 
            ? settings.value.downloadFolder 
            : '${dir?.path}/Download';
      } else {
        _downloadPath = settings.value.downloadFolder.isNotEmpty 
            ? settings.value.downloadFolder 
            : '/storage/emulated/0/Download';
      }
      final downloadDir = Directory(_downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
    } else if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      _downloadPath = settings.value.downloadFolder.isNotEmpty 
          ? settings.value.downloadFolder 
          : '${dir.path}/Downloads';
      final downloadDir = Directory(_downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
    }
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid && !kIsWeb) {
      final status = await Permission.storage.request();
      if (status.isDenied && Get.context != null && Get.context!.mounted) {
        Get.snackbar(
          'Permission Required',
          'Storage permission is needed to download files',
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Settings', style: TextStyle(color: Colors.white)),
          ),
        );
      }
    }
  }

  // ==================== VIDEO QUALITY DETECTION ====================
  Future<List<VideoQuality>> detectVideoQualities(String url) async {
    try {
      debugPrint('Detecting video qualities for: $url');
      
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        return await _extractYouTubeQualities(url);
      } else if (url.contains('vimeo.com')) {
        return await _extractVimeoQualities(url);
      } else if (url.contains('.m3u8')) {
        return await _extractM3U8Qualities(url);
      } else {
        return await _extractGenericQualities(url);
      }
    } catch (e) {
      debugPrint('Error detecting video qualities: $e');
      return [];
    }
  }

  Future<List<VideoQuality>> _extractYouTubeQualities(String url) async {
    final qualities = <VideoQuality>[];
    
    try {
      qualities.addAll([
        VideoQuality(quality: '144p', url: url, format: 'mp4'),
        VideoQuality(quality: '360p', url: url, format: 'mp4'),
        VideoQuality(quality: '720p', url: url, format: 'mp4'),
        VideoQuality(quality: '1080p', url: url, format: 'mp4'),
      ]);
    } catch (e) {
      debugPrint('Error extracting YouTube qualities: $e');
    }
    
    return qualities;
  }

  Future<List<VideoQuality>> _extractVimeoQualities(String url) async {
    final qualities = <VideoQuality>[];
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = response.body;
        final configMatch = RegExp(r'var config = ({.*?});').firstMatch(body);
        if (configMatch != null) {
          final configJson = jsonDecode(configMatch.group(1)!);
          final files = configJson['request']['files']['progressive'];
          
          for (var file in files) {
            qualities.add(VideoQuality(
              quality: file['quality'],
              url: file['url'],
              fileSize: file['size'],
              format: file['mime']?.split('/').last,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting Vimeo qualities: $e');
    }
    
    return qualities;
  }

  Future<List<VideoQuality>> _extractM3U8Qualities(String url) async {
    final qualities = <VideoQuality>[];
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].startsWith('#EXT-X-STREAM-INF')) {
            final resolutionMatch = RegExp(r'RESOLUTION=(\d+x\d+)').firstMatch(lines[i]);
            final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(lines[i]);
            
            if (resolutionMatch != null && i + 1 < lines.length) {
              final resolution = resolutionMatch.group(1)!.split('x')[1];
              final streamUrl = lines[i + 1];
              
              qualities.add(VideoQuality(
                quality: '${resolution}p',
                url: streamUrl.startsWith('http') ? streamUrl : url.substring(0, url.lastIndexOf('/') + 1) + streamUrl,
                fileSize: bandwidthMatch != null ? int.parse(bandwidthMatch.group(1)!) : null,
                format: 'm3u8',
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting M3U8 qualities: $e');
    }
    
    return qualities;
  }

  Future<List<VideoQuality>> _extractGenericQualities(String url) async {
    final qualities = <VideoQuality>[];
    
    final commonQualities = ['360p', '480p', '720p', '1080p'];
    for (var quality in commonQualities) {
      if (url.contains(quality)) {
        qualities.add(VideoQuality(quality: quality, url: url));
        break;
      }
    }
    
    if (qualities.isEmpty) {
      qualities.add(VideoQuality(quality: 'Default', url: url));
    }
    
    return qualities;
  }

  // ==================== M3U8 DOWNLOAD ====================
  Future<void> downloadM3U8(String url, String fileName, {String? selectedQuality}) async {
    try {
      if (_isDuplicateDownload(url, fileName, null)) {
        if (Get.context != null && Get.context!.mounted) {
          Get.snackbar(
            'Already Downloading',
            'This file is already in your download queue',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
        return;
      }

      debugPrint('Starting M3U8 download: $url');
      
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final tempDir = Directory('$_downloadPath/.temp_$taskId');
      await tempDir.create(recursive: true);

      final segments = await _parseM3U8Playlist(url);
      debugPrint('Found ${segments.length} segments');

      if (segments.isEmpty) {
        throw Exception('No segments found in M3U8 playlist');
      }

      final item = DownloadItem(
        taskId: taskId,
        fileName: fileName,
        url: url,
        savedDir: _downloadPath,
        status: DownloadTaskStatus.running,
        progress: 0,
        fileSize: 0,
        startTime: DateTime.now(),
        isM3U8: true,
        selectedQuality: selectedQuality,
      );

      downloadItems.add(item);
      _activeSpeedTrackers[taskId] = SpeedTracker();

      if (settings.value.showNotifications) {
        _showProgressNotification(taskId, 0, 0, segments.length);
      }

      final segmentFiles = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final segmentUrl = segments[i];
        final segmentFile = '${tempDir.path}/segment_$i.ts';
        
        await _downloadSegment(segmentUrl, segmentFile);
        segmentFiles.add(segmentFile);

        final progress = ((i + 1) / segments.length * 100).toInt();
        updateDownloadItem(taskId, progress: progress);
        
        if (settings.value.showNotifications) {
          _updateNotificationThrottled(taskId, progress, i + 1, segments.length);
        }
      }

      await _mergeM3U8Segments(segmentFiles, '$_downloadPath/$fileName', taskId);
      await tempDir.delete(recursive: true);

      // Mark as complete
      updateDownloadItem(
        taskId,
        status: DownloadTaskStatus.complete,
        progress: 100,
      );

      // CRITICAL FIX: Mark as completed
      _completedDownloads.add(taskId);

      // Clean up all tracking
      activeDownloads.remove(taskId);
      _activeSpeedTrackers.remove(taskId);
      downloadQueue.remove(taskId);
      _manuallyPausedItems.remove(taskId);
      _pauseInProgress.remove(taskId);

      if (settings.value.showNotifications) {
        _showCompleteNotification(taskId, fileName);
      }

      _showDownloadCompleteSnackbar(fileName);

      await _saveDownloads();
      await _loadStorageInfo();

      debugPrint('M3U8 download completed: $fileName');
    } catch (e) {
      debugPrint('Error downloading M3U8: $e');
      if (Get.context != null && Get.context!.mounted) {
        Get.snackbar('Error', 'Failed to download video: $e');
      }
    }
  }

  Future<List<String>> _parseM3U8Playlist(String url) async {
    final segments = <String>[];
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final baseUrl = url.substring(0, url.lastIndexOf('/') + 1);

        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty && !line.startsWith('#')) {
            final segmentUrl = line.startsWith('http') ? line : baseUrl + line;
            segments.add(segmentUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing M3U8 playlist: $e');
    }
    
    return segments;
  }

  Future<void> _downloadSegment(String url, String outputPath) async {
    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(seconds: 30));

      final file = File(outputPath);
      sink = file.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
      }

      await sink.flush();
    } finally {
      await sink?.close();
      client.close();
    }
  }

  Future<void> _mergeM3U8Segments(List<String> segmentFiles, String outputPath, String taskId) async {
    File? concatFile;
    try {
      debugPrint('Merging ${segmentFiles.length} segments...');

      concatFile = File('${_downloadPath}/.concat_$taskId.txt');
      final concatContent = segmentFiles.map((file) => "file '${file.replaceAll("'", "\\'")}'")
          .join('\n');
      await concatFile.writeAsString(concatContent);

      final command = '-f concat -safe 0 -i "${concatFile.path}" -c copy "$outputPath"';
      
      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          debugPrint('FFmpegKit merge successful');
        } else {
          final failStackTrace = await session.getFailStackTrace();
          debugPrint('FFmpegKit merge failed: $failStackTrace');
          throw Exception('FFmpegKit merge failed');
        }
      });
    } catch (e) {
      debugPrint('Error merging M3U8 segments: $e');
      throw e;
    } finally {
      try {
        await concatFile?.delete();
      } catch (e) {
        debugPrint('Error deleting concat file: $e');
      }
    }
  }

  // ==================== STANDARD DOWNLOAD ====================
  Future<void> _startDownload(DownloadItem item, {int retryCount = 0}) async {
    final client = http.Client();
    activeDownloads[item.taskId] = client;
    _activeSpeedTrackers[item.taskId] = SpeedTracker();

    try {
      debugPrint('Starting download: ${item.fileName}');

      updateDownloadItem(
        item.taskId,
        status: DownloadTaskStatus.running,
      );

      final request = http.Request('GET', Uri.parse(item.url));
      
      if (item.downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=${item.downloadedBytes}-';
        debugPrint('Resuming from byte: ${item.downloadedBytes}');
      }
      
      final response = await client.send(request);

      if (!(response.statusCode == 200 || response.statusCode == 206)) {
        throw Exception('HTTP ${response.statusCode}');
      }

      int totalBytes = item.fileSize;
      
      if (totalBytes == 0 && response.contentLength != null) {
        totalBytes = response.contentLength!;
        updateDownloadItem(item.taskId, fileSize: totalBytes);
      }

      final file = File('${_downloadPath}/${item.fileName}');
      final sink = file.openWrite(mode: item.downloadedBytes > 0 ? FileMode.append : FileMode.write);

      int receivedBytes = item.downloadedBytes;

      if (settings.value.showNotifications) {
        _showProgressNotification(item.taskId, item.progress, receivedBytes, totalBytes);
      }

      await for (var data in response.stream) {
        if (!activeDownloads.containsKey(item.taskId)) {
          await sink.close();
          debugPrint('Download stopped by user: ${item.fileName}');
          return;
        }

        sink.add(data);
        receivedBytes += data.length;

        final progress = totalBytes > 0 ? (receivedBytes / totalBytes * 100).toInt() : 0;

        updateDownloadItem(
          item.taskId,
          progress: progress,
          downloadedBytes: receivedBytes,
        );

        if (settings.value.showNotifications) {
          _updateNotificationThrottled(item.taskId, progress, receivedBytes, totalBytes);
        }

        if (settings.value.speedLimitKBps > 0) {
          final maxBytesPerSecond = settings.value.speedLimitKBps * 1024;
          final delayMs = (data.length * 1000 / maxBytesPerSecond).round();
          if (delayMs > 0) {
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        }
      }

      await sink.flush();
      await sink.close();

      // Mark as complete
      updateDownloadItem(
        item.taskId,
        status: DownloadTaskStatus.complete,
        progress: 100,
      );

      // CRITICAL FIX: Mark as completed
      _completedDownloads.add(item.taskId);

      // Clean up
      activeDownloads.remove(item.taskId);
      _activeSpeedTrackers.remove(item.taskId);
      downloadQueue.remove(item.taskId);
      _manuallyPausedItems.remove(item.taskId);
      _pauseInProgress.remove(item.taskId);

      if (settings.value.showNotifications) {
        _showCompleteNotification(item.taskId, item.fileName);
      }

      _showDownloadCompleteSnackbar(item.fileName);

      await _saveDownloads();
      await _loadStorageInfo();

      debugPrint('Download completed: ${item.fileName}');
    } catch (e) {
      debugPrint('Download error: $e');
      activeDownloads.remove(item.taskId);

      if (retryCount < settings.value.autoRetryCount) {
        debugPrint('Retrying download (${retryCount + 1}/${settings.value.autoRetryCount})');
        await Future.delayed(const Duration(seconds: 2));
        await _startDownload(item, retryCount: retryCount + 1);
      } else {
        updateDownloadItem(item.taskId, status: DownloadTaskStatus.failed);
        if (settings.value.showNotifications) {
          _showFailedNotification(item.taskId, item.fileName);
        }
      }
    }
  }

  // ==================== MULTI-THREADED DOWNLOAD ====================
  Future<void> startMultiThreadedDownload(DownloadItem item) async {
    if (!settings.value.enableMultiThreading) {
      return _startDownload(item);
    }

    try {
      debugPrint('Starting multi-threaded download: ${item.fileName}');

      final client = http.Client();
      final headRequest = http.Request('HEAD', Uri.parse(item.url));
      final headResponse = await client.send(headRequest);
      client.close();

      final totalSize = headResponse.contentLength ?? 0;
      if (totalSize == 0) {
        debugPrint('File size unknown, falling back to single-threaded');
        return _startDownload(item);
      }

      final acceptsRanges = headResponse.headers['accept-ranges'] == 'bytes';
      if (!acceptsRanges) {
        debugPrint('Server does not support range requests, falling back');
        return _startDownload(item);
      }

      final chunkSize = (totalSize / settings.value.threadCount).ceil();
      final chunks = <DownloadChunk>[];

      for (var i = 0; i < settings.value.threadCount; i++) {
        final start = i * chunkSize;
        final end = i == settings.value.threadCount - 1 
            ? totalSize - 1 
            : (i + 1) * chunkSize - 1;

        chunks.add(DownloadChunk(
          index: i,
          start: start,
          end: end,
          filePath: '${_downloadPath}/.chunk_${item.taskId}_$i.tmp',
        ));
      }

      final updatedItem = item.copyWith(
        chunks: chunks,
        fileSize: totalSize,
        isMultiThreaded: true,
        status: DownloadTaskStatus.running,
      );

      final index = downloadItems.indexWhere((i) => i.taskId == item.taskId);
      if (index != -1) {
        downloadItems[index] = updatedItem;
      }

      _activeSpeedTrackers[item.taskId] = SpeedTracker();
      activeDownloads[item.taskId] = http.Client();

      if (settings.value.showNotifications) {
        _showProgressNotification(item.taskId, 0, 0, totalSize);
      }

      final futures = chunks.map((chunk) => _downloadChunk(updatedItem, chunk));
      await Future.wait(futures);

      await _mergeChunks(updatedItem);

      for (var chunk in chunks) {
        final file = File(chunk.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      updateDownloadItem(
        item.taskId,
        status: DownloadTaskStatus.complete,
        progress: 100,
      );

      // CRITICAL FIX: Mark as completed
      _completedDownloads.add(item.taskId);

      // Clean up all tracking
      activeDownloads.remove(item.taskId);
      _activeSpeedTrackers.remove(item.taskId);
      downloadQueue.remove(item.taskId);
      _manuallyPausedItems.remove(item.taskId);
      _pauseInProgress.remove(item.taskId);

      if (settings.value.showNotifications) {
        _showCompleteNotification(item.taskId, item.fileName);
      }

      _showDownloadCompleteSnackbar(item.fileName);

      await _saveDownloads();
      await _loadStorageInfo();

      debugPrint('Multi-threaded download completed: ${item.fileName}');
    } catch (e) {
      debugPrint('Error in multi-threaded download: $e');
      updateDownloadItem(item.taskId, status: DownloadTaskStatus.failed);
      activeDownloads.remove(item.taskId);
      
      if (settings.value.showNotifications) {
        _showFailedNotification(item.taskId, item.fileName);
      }
    }
  }

  Future<void> _downloadChunk(DownloadItem item, DownloadChunk chunk) async {
    final client = http.Client();
    
    try {
      final request = http.Request('GET', Uri.parse(item.url));
      request.headers['Range'] = 'bytes=${chunk.start + chunk.downloadedBytes}-${chunk.end}';

      final response = await client.send(request);

      if (!(response.statusCode == 200 || response.statusCode == 206)) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final file = File(chunk.filePath);
      final sink = file.openWrite(mode: FileMode.append);

      await for (var data in response.stream) {
        if (!activeDownloads.containsKey(item.taskId)) {
          break;
        }

        sink.add(data);
        chunk.downloadedBytes += data.length;

        _updateMultiThreadProgress(item.taskId);
      }

      await sink.flush();
      await sink.close();

      chunk.isComplete = true;
      debugPrint('Chunk ${chunk.index} completed');
    } catch (e) {
      debugPrint('Error downloading chunk ${chunk.index}: $e');
      throw e;
    } finally {
      client.close();
    }
  }

  void _updateMultiThreadProgress(String taskId) {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null || item.chunks == null) return;

    final totalDownloaded = item.chunks!
        .fold<int>(0, (sum, chunk) => sum + chunk.downloadedBytes);
    
    final progress = item.fileSize > 0 
        ? (totalDownloaded / item.fileSize * 100).toInt() 
        : 0;

    updateDownloadItem(
      taskId,
      downloadedBytes: totalDownloaded,
      progress: progress,
    );

    if (settings.value.showNotifications) {
      _updateNotificationThrottled(taskId, progress, totalDownloaded, item.fileSize);
    }
  }

  Future<void> _mergeChunks(DownloadItem item) async {
    try {
      debugPrint('Merging ${item.chunks!.length} chunks...');

      final outputFile = File('${_downloadPath}/${item.fileName}');
      final sink = outputFile.openWrite();

      for (var chunk in item.chunks!) {
        final chunkFile = File(chunk.filePath);
        if (await chunkFile.exists()) {
          final bytes = await chunkFile.readAsBytes();
          sink.add(bytes);
        }
      }

      await sink.flush();
      await sink.close();

      debugPrint('Chunks merged successfully');
    } catch (e) {
      debugPrint('Error merging chunks: $e');
      throw e;
    }
  }

  // ==================== PAUSE/RESUME/CANCEL (COMPLETELY FIXED) ====================
  Future<void> pauseDownload(String taskId) async {
    // CRITICAL FIX: Prevent duplicate pause operations
    if (_pauseInProgress.contains(taskId)) {
      debugPrint('⚠️ Pause already in progress for: $taskId');
      return;
    }
    
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) {
      debugPrint('⚠️ Cannot pause: item not found');
      return;
    }
    
    if (item.status != DownloadTaskStatus.running) {
      debugPrint('⚠️ Cannot pause: item not running (status: ${item.status})');
      return;
    }

    // Lock this operation
    _pauseInProgress.add(taskId);
    
    // CRITICAL: Mark as manually paused FIRST (prevents queue from re-adding)
    _manuallyPausedItems.add(taskId);
    
    try {
      debugPrint('🔴 Pausing download: ${item.fileName}');

      // 1. Remove from queue IMMEDIATELY (prevents auto-restart)
      downloadQueue.remove(taskId);

      // 2. Close HTTP client
      final client = activeDownloads[taskId];
      if (client != null) {
        client.close();
      }
      
      // 3. Remove from active downloads
      activeDownloads.remove(taskId);
      _activeSpeedTrackers.remove(taskId);

      // 4. Update status to paused
      final index = downloadItems.indexWhere((i) => i.taskId == taskId);
      if (index != -1) {
        downloadItems[index] = downloadItems[index].copyWith(
          status: DownloadTaskStatus.paused,
        );
        downloadItems.refresh();
      }
      
      // 5. Save state immediately
      await _saveDownloads();

      debugPrint('✅ Download paused successfully: ${item.fileName}');

      // Show notification
      if (Get.context != null && Get.context!.mounted) {
        Get.snackbar(
          'Download Paused',
          item.fileName,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('❌ Error pausing download: $e');
      // If error, remove from manually paused
      _manuallyPausedItems.remove(taskId);
    } finally {
      // CRITICAL FIX: Delay lock removal to prevent immediate queue processing
      await Future.delayed(const Duration(seconds: 3));
      _pauseInProgress.remove(taskId);
      debugPrint('🔓 Pause lock removed for: $taskId');
    }
  }

  Future<void> resumeDownload(String taskId) async {
    try {
      final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
      if (item == null) {
        debugPrint('Cannot resume: item not found');
        return;
      }
      
      if (item.status != DownloadTaskStatus.paused && item.status != DownloadTaskStatus.failed) {
        debugPrint('Cannot resume: item status is ${item.status}');
        return;
      }

      debugPrint('Resuming download: ${item.fileName} from ${item.downloadedBytes} bytes');

      // Remove from manually paused list
      _manuallyPausedItems.remove(taskId);
      _pauseInProgress.remove(taskId);

      // Update status to enqueued first
      updateDownloadItem(taskId, status: DownloadTaskStatus.enqueued);
      
      // Add to queue if not already there
      if (!downloadQueue.contains(taskId)) {
        downloadQueue.add(taskId);
      }

      // Save state
      await _saveDownloads();

      // Trigger queue processing
      await _processDownloadQueue();

      if (Get.context != null && Get.context!.mounted) {
        Get.snackbar(
          'Download Resumed',
          item.fileName,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      debugPrint('Error resuming download: $e');
      if (Get.context != null && Get.context!.mounted) {
        Get.snackbar(
          'Resume Failed',
          'Could not resume download',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> retryDownload(String taskId) async {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return;

    debugPrint('Retrying download: ${item.fileName}');

    _retryCounters[taskId] = 0;
    _manuallyPausedItems.remove(taskId);
    _pauseInProgress.remove(taskId);
    
    updateDownloadItem(
      taskId,
      status: DownloadTaskStatus.enqueued,
      progress: 0,
      downloadedBytes: 0,
    );
    
    if (!downloadQueue.contains(taskId)) {
      downloadQueue.add(taskId);
    }
    
    await _saveDownloads();
    await _processDownloadQueue();
  }

  Future<void> cancelDownload(String taskId) async {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return;

    debugPrint('Canceling download: ${item.fileName}');

    final client = activeDownloads[taskId];
    client?.close();
    activeDownloads.remove(taskId);
    _activeSpeedTrackers.remove(taskId);
    downloadQueue.remove(taskId);
    _manuallyPausedItems.remove(taskId);
    _pauseInProgress.remove(taskId);

    updateDownloadItem(taskId, status: DownloadTaskStatus.canceled);

    final file = File('${_downloadPath}/${item.fileName}');
    if (await file.exists()) {
      await file.delete();
    }

    await _saveDownloads();
  }

  // ==================== DELETE DOWNLOAD (COMPLETELY FIXED) ====================
  Future<void> deleteDownload(String taskId) async {
    // CRITICAL FIX: Check if already deleting
    if (_deleteInProgress.contains(taskId)) {
      debugPrint('⚠️ Delete already in progress for: $taskId');
      return;
    }
    
    _deleteInProgress.add(taskId);
    
    try {
      final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
      if (item == null) {
        debugPrint('⚠️ Delete: Item not found');
        return;
      }

      debugPrint('🗑️ Deleting download: ${item.fileName}');

      // Stop download if running
      if (item.status == DownloadTaskStatus.running) {
        final client = activeDownloads[taskId];
        if (client != null) {
          client.close();
        }
        activeDownloads.remove(taskId);
        _activeSpeedTrackers.remove(taskId);
      }

      // Remove from all tracking
      downloadQueue.remove(taskId);
      _manuallyPausedItems.remove(taskId);
      _pauseInProgress.remove(taskId);
      _completedDownloads.remove(taskId);

      // Delete file safely
      try {
        final file = File('${_downloadPath}/${item.fileName}');
        if (await file.exists()) {
          await file.delete();
          debugPrint('✅ File deleted: ${item.fileName}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not delete file: $e');
      }

      // Delete chunks if multi-threaded
      if (item.chunks != null) {
        for (var chunk in item.chunks!) {
          try {
            final chunkFile = File(chunk.filePath);
            if (await chunkFile.exists()) {
              await chunkFile.delete();
            }
          } catch (e) {
            debugPrint('⚠️ Could not delete chunk: $e');
          }
        }
      }

      // Remove from list
      downloadItems.removeWhere((i) => i.taskId == taskId);
      selectedItems.remove(taskId);
      
      // Save state
      await _saveDownloads();
      await _loadStorageInfo();

      debugPrint('✅ Download deleted successfully');

      // CRITICAL FIX: Use safe delayed snackbar
      _showSafeSnackbar(
        'Deleted',
        item.fileName,
        backgroundColor: Colors.red.shade400,
      );
    } catch (e) {
      debugPrint('❌ Error in deleteDownload: $e');
    } finally {
      _deleteInProgress.remove(taskId);
    }
  }

  // ==================== RENAME FILE (COMPLETELY FIXED) ====================
  Future<void> renameFile(String taskId, String newName) async {
    // CRITICAL FIX: Check if already renaming
    if (_renameInProgress.contains(taskId)) {
      debugPrint('⚠️ Rename already in progress for: $taskId');
      return;
    }
    
    _renameInProgress.add(taskId);
    
    try {
      debugPrint('🔄 Starting rename for taskId: $taskId to: $newName');
      
      final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
      if (item == null) {
        debugPrint('❌ Rename: Item not found');
        _showSafeSnackbar(
          'Error',
          'Download not found',
          backgroundColor: Colors.red,
        );
        return;
      }
      
      // Validate new name
      if (newName.trim().isEmpty) {
        debugPrint('❌ Rename: Empty name');
        _showSafeSnackbar(
          'Invalid Name',
          'Please enter a valid file name',
          backgroundColor: Colors.orange,
        );
        return;
      }
      
      // Sanitize name
      final sanitizedName = _sanitizeFileName(newName.trim());
      if (sanitizedName.isEmpty) {
        debugPrint('❌ Rename: Name became empty after sanitization');
        _showSafeSnackbar(
          'Invalid Name',
          'File name contains invalid characters',
          backgroundColor: Colors.orange,
        );
        return;
      }
      
      // Check if same name
      if (sanitizedName == item.fileName) {
        debugPrint('⚠️ Rename: Same name, skipping');
        _showSafeSnackbar(
          'No Change',
          'File already has this name',
          backgroundColor: Colors.blue,
        );
        return;
      }
      
      // Check if new name already exists
      final newFilePath = '$_downloadPath/$sanitizedName';
      final newFile = File(newFilePath);
      if (await newFile.exists()) {
        debugPrint('❌ Rename: File already exists');
        _showSafeSnackbar(
          'Name Exists',
          'A file with this name already exists',
          backgroundColor: Colors.orange,
        );
        return;
      }
      
      // Get old file
      final oldFilePath = '$_downloadPath/${item.fileName}';
      final oldFile = File(oldFilePath);
      
      if (!await oldFile.exists()) {
        debugPrint('❌ Rename: Original file not found');
        _showSafeSnackbar(
          'File Not Found',
          'The original file does not exist',
          backgroundColor: Colors.red,
        );
        return;
      }
      
      // Perform rename
      try {
        await oldFile.rename(newFilePath);
        debugPrint('✅ File renamed successfully');
      } catch (e) {
        debugPrint('❌ Rename operation failed: $e');
        _showSafeSnackbar(
          'Rename Failed',
          'Could not rename file: Permission denied',
          backgroundColor: Colors.red,
        );
        return;
      }
      
      // Update in download list
      final index = downloadItems.indexWhere((i) => i.taskId == taskId);
      if (index != -1) {
        downloadItems[index] = item.copyWith(fileName: sanitizedName);
        downloadItems.refresh();
        debugPrint('✅ Download item updated');
      }
      
      // Save state
      await _saveDownloads();
      
      // Show success
      _showSafeSnackbar(
        'Renamed',
        'File renamed to: $sanitizedName',
        backgroundColor: Colors.green,
      );
      
      debugPrint('✅ Rename completed successfully');
      
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error in renameFile: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Safe error message
      _showSafeSnackbar(
        'Error',
        'An unexpected error occurred',
        backgroundColor: Colors.red,
      );
    } finally {
      _renameInProgress.remove(taskId);
    }
  }

  // ==================== ENQUEUE WITH QUALITY SELECTION ====================
  Future<void> enqueueDownloadWithQualitySelection(String url, String fileName) async {
    try {
      if (_isDuplicateDownload(url, fileName, null)) {
        _showSafeDialog(
          title: 'File Already Exists',
          content: 'This file is already downloaded, currently downloading, or in the waiting queue.',
          icon: Icons.warning,
          iconColor: Colors.orange,
        );
        return;
      }

      if (settings.value.autoDetectM3U8 || url.contains('youtube') || url.contains('vimeo')) {
        final qualities = await detectVideoQualities(url);
        
        if (qualities.length > 1) {
          _showQualitySelectionDialog(url, fileName, qualities);
          return;
        }
      }

      if (isM3U8Url(url)) {
        final shouldDownload = await _showDownloadPermissionDialog(url, fileName);
        if (shouldDownload) {
          await downloadM3U8(url, fileName);
        }
        return;
      }

      await enqueueDownload(url, fileName);
    } catch (e) {
      debugPrint('Error enqueueing download: $e');
      _showSafeSnackbar('Error', 'Failed to start download', backgroundColor: Colors.red);
    }
  }

  void _showQualitySelectionDialog(String url, String fileName, List<VideoQuality> qualities) {
    if (Get.context == null || !Get.context!.mounted || Get.isDialogOpen == true) {
      debugPrint('Cannot show quality dialog - invalid context or dialog already open');
      return;
    }
    
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.high_quality, color: Colors.blue),
            SizedBox(width: 8),
            Text('Select Quality'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: qualities.map((quality) {
              return ListTile(
                leading: const Icon(Icons.video_library),
                title: Text(quality.quality),
                subtitle: quality.fileSize != null 
                    ? Text(formatFileSize(quality.fileSize!.toDouble()))
                    : null,
                onTap: () async {
                  if (Get.isDialogOpen == true) Get.back();
                  
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  final shouldDownload = await _showDownloadPermissionDialog(quality.url, fileName);
                  if (shouldDownload) {
                    if (quality.format == 'm3u8') {
                      downloadM3U8(quality.url, fileName, selectedQuality: quality.quality);
                    } else {
                      enqueueDownload(quality.url, fileName, showWarning: false);
                    }
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> enqueueDownload(String url, String fileName, {bool showWarning = true}) async {
    try {
      if (_isDuplicateDownload(url, fileName, null)) {
        _showSafeDialog(
          title: 'File Already Exists',
          content: 'This file is already downloaded, currently downloading, or in the waiting queue.',
          icon: Icons.warning,
          iconColor: Colors.orange,
        );
        return;
      }

      final shouldDownload = await _showDownloadPermissionDialog(url, fileName);
      if (!shouldDownload) return;

      final uniqueFileName = _generateUniqueFileName(fileName);
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final fileType = detectFileType(uniqueFileName, url);
      final isM3U8 = isM3U8Url(url);

      final newItem = DownloadItem(
        taskId: taskId,
        fileName: uniqueFileName,
        url: url,
        savedDir: _downloadPath,
        status: DownloadTaskStatus.enqueued,
        progress: 0,
        fileSize: 0,
        startTime: DateTime.now(),
        downloadedBytes: 0,
        fileType: fileType,
        isM3U8: isM3U8,
      );

      downloadItems.add(newItem);
      
      if (!downloadQueue.contains(taskId)) {
        downloadQueue.add(taskId);
      }

      _showSafeSnackbar(
        'Download Started',
        uniqueFileName,
        backgroundColor: Colors.green,
        icon: Icons.download,
      );

      await _saveDownloads();
      await _processDownloadQueue();
    } catch (e) {
      debugPrint('Error enqueuing download: $e');
      _showSafeSnackbar('Error', 'Failed to add download', backgroundColor: Colors.red);
    }
  }

  // ==================== NOTIFICATIONS ====================
  void _showProgressNotification(String taskId, int progress, int downloaded, int total) {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return;

    final notificationId = _taskNotificationIds.putIfAbsent(taskId, () => ++_notificationIdCounter);

    _notificationsPlugin.show(
      notificationId,
      'Downloading ${item.fileName}',
      '$progress% • ${formatFileSize(downloaded.toDouble())} / ${formatFileSize(total.toDouble())}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Download progress notifications',
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          onlyAlertOnce: true,
          ongoing: true,
        ),
      ),
      payload: 'download_progress',
    );
  }

  void _showCompleteNotification(String taskId, String fileName) {
    final notificationId = _taskNotificationIds[taskId] ?? ++_notificationIdCounter;
    _notificationsPlugin.show(
      notificationId,
      'Download Complete',
      fileName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Download notifications',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
      payload: 'download_complete',
    );
    
    // Auto-dismiss notification after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _notificationsPlugin.cancel(notificationId);
      _taskNotificationIds.remove(taskId);
    });
  }

  void _showFailedNotification(String taskId, String fileName) {
    final notificationId = _taskNotificationIds[taskId] ?? ++_notificationIdCounter;
    _notificationsPlugin.show(
      notificationId,
      'Download Failed',
      fileName,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'download_channel',
          'Downloads',
          channelDescription: 'Download notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'download_failed',
    );
  }

  void _updateNotificationThrottled(String taskId, int progress, int downloaded, int total) {
    final now = DateTime.now();
    final lastUpdate = _notificationUpdateTimers[taskId];
    
    if (lastUpdate == null || now.difference(lastUpdate).inSeconds >= 3) {
      _notificationUpdateTimers[taskId] = now;
      _showProgressNotification(taskId, progress, downloaded, total);
    }
  }

  // ==================== SAFE UI HELPERS (CRITICAL FIX) ====================
  void _showSafeSnackbar(String title, String message, {
    Color backgroundColor = Colors.blue,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) {
    try {
      if (Get.context != null && Get.context!.mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (Get.context != null && Get.context!.mounted) {
            Get.snackbar(
              title,
              message,
              snackPosition: SnackPosition.BOTTOM,
              duration: duration,
              backgroundColor: backgroundColor,
              colorText: Colors.white,
              icon: icon != null ? Icon(icon, color: Colors.white) : null,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error showing snackbar: $e');
    }
  }

  void _showSafeDialog({
    required String title,
    required String content,
    IconData? icon,
    Color? iconColor,
  }) {
    try {
      if (Get.context == null || !Get.context!.mounted || Get.isDialogOpen == true) {
        return;
      }
      
      Get.dialog(
        AlertDialog(
          title: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) Get.back();
              },
              child: const Text('OK'),
            ),
          ],
        ),
        barrierDismissible: true,
      );
    } catch (e) {
      debugPrint('Error showing dialog: $e');
    }
  }

  // CRITICAL FIX: Use snackbar instead of dialog for completion
  void _showDownloadCompleteSnackbar(String fileName) {
    try {
      if (Get.context == null || !Get.context!.mounted) {
        return;
      }
      
      Get.snackbar(
        'Download Complete',
        fileName,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green,
        colorText: Colors.white,
        icon: const Icon(Icons.check_circle, color: Colors.white),
        shouldIconPulse: true,
        mainButton: TextButton(
          onPressed: () {
            Get.toNamed('/downloads');
          },
          child: const Text('View', style: TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      debugPrint('Error showing download complete notification: $e');
    }
  }

  // ==================== CONNECTIVITY & BATTERY ====================
  void _initializeConnectivityMonitoring() {
    _connectivity.checkConnectivity().then((results) {
      isWifiConnected.value = results.contains(ConnectivityResult.wifi);
    });
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasWifi = results.contains(ConnectivityResult.wifi);
      final hasConnection = results.isNotEmpty && !results.contains(ConnectivityResult.none);
      
      isWifiConnected.value = hasWifi;
      
      if (settings.value.autoResume && hasConnection) {
        _handleNetworkReconnect();
      }
      
      if (settings.value.wifiOnly && !hasWifi) {
        _pauseAllActiveDownloads('Waiting for Wi-Fi connection');
      }
    });
  }

  void _handleNetworkReconnect() {
    debugPrint('Network reconnected - checking for paused downloads');
    
    for (var item in downloadItems) {
      if (item.status == DownloadTaskStatus.paused && !_isManuallyPaused(item.taskId)) {
        resumeDownload(item.taskId);
      }
    }
  }

  bool _isManuallyPaused(String taskId) {
    return _manuallyPausedItems.contains(taskId);
  }

  void _pauseAllActiveDownloads(String reason) {
    debugPrint('Pausing all downloads: $reason');
    
    for (var item in downloadItems) {
      if (item.status == DownloadTaskStatus.running) {
        final client = activeDownloads[item.taskId];
        client?.close();
        activeDownloads.remove(item.taskId);
        _activeSpeedTrackers.remove(item.taskId);
        downloadQueue.remove(item.taskId);
        updateDownloadItem(item.taskId, status: DownloadTaskStatus.paused);
      }
    }
    
    _showSafeSnackbar('Downloads Paused', reason);
  }

  void _initializeBatteryMonitoring() {
    _battery.batteryLevel.then((level) {
      batteryLevel.value = level;
    });
    
    _batteryTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      final level = await _battery.batteryLevel;
      batteryLevel.value = level;
    });
    
    _batterySubscription = _battery.onBatteryStateChanged.listen((state) {
      isBatterySaverActive.value = state == BatteryState.charging ? false : 
                                    batteryLevel.value < 20;
      
      if (settings.value.batterySaver && isBatterySaverActive.value) {
        _handleBatterySaverMode();
      }
    });
  }

  void _handleBatterySaverMode() {
    debugPrint('Battery saver activated');
    
    if (activeDownloads.length > 1) {
      final downloadsToPause = activeDownloads.keys.skip(1).toList();
      for (var taskId in downloadsToPause) {
        pauseDownload(taskId);
      }
    }
  }

  // ==================== SETTINGS ====================
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('download_settings');
      
      if (settingsJson != null) {
        settings.value = DownloadSettings.fromJson(jsonDecode(settingsJson));
      }
      
      if (settings.value.downloadFolder.isNotEmpty) {
        _downloadPath = settings.value.downloadFolder;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_settings', jsonEncode(settings.value.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> updateSettings({
    int? maxParallelDownloads,
    String? downloadFolder,
    bool? autoResume,
    int? autoRetryCount,
    bool? showNotifications,
    bool? wifiOnly,
    int? speedLimitKBps,
    bool? batterySaver,
    bool? foregroundService,
    bool? enableMultiThreading,
    int? threadCount,
    bool? autoDetectM3U8,
  }) async {
    settings.value = DownloadSettings(
      maxParallelDownloads: maxParallelDownloads ?? settings.value.maxParallelDownloads,
      downloadFolder: downloadFolder ?? settings.value.downloadFolder,
      autoResume: autoResume ?? settings.value.autoResume,
      autoRetryCount: autoRetryCount ?? settings.value.autoRetryCount,
      showNotifications: showNotifications ?? settings.value.showNotifications,
      wifiOnly: wifiOnly ?? settings.value.wifiOnly,
      speedLimitKBps: speedLimitKBps ?? settings.value.speedLimitKBps,
      batterySaver: batterySaver ?? settings.value.batterySaver,
      foregroundService: foregroundService ?? settings.value.foregroundService,
      enableMultiThreading: enableMultiThreading ?? settings.value.enableMultiThreading,
      threadCount: threadCount ?? settings.value.threadCount,
      autoDetectM3U8: autoDetectM3U8 ?? settings.value.autoDetectM3U8,
    );
    
    await saveSettings();
    
    if (downloadFolder != null && downloadFolder.isNotEmpty) {
      _downloadPath = downloadFolder;
    }
  }

  // ==================== UTILITIES ====================
  String detectFileType(String fileName, String url) {
    final lowerFileName = fileName.toLowerCase();
    final lowerUrl = url.toLowerCase();
    
    if (lowerFileName.endsWith('.mp4') || lowerFileName.endsWith('.avi') ||
        lowerFileName.endsWith('.mkv') || lowerFileName.endsWith('.mov') ||
        lowerFileName.endsWith('.wmv') || lowerFileName.endsWith('.flv') ||
        lowerFileName.endsWith('.webm') || lowerFileName.endsWith('.m3u8') ||
        lowerUrl.contains('video') || lowerUrl.contains('.m3u8')) {
      return 'video';
    }
    
    if (lowerFileName.endsWith('.mp3') || lowerFileName.endsWith('.wav') ||
        lowerFileName.endsWith('.aac') || lowerFileName.endsWith('.ogg') ||
        lowerFileName.endsWith('.flac') || lowerFileName.endsWith('.m4a')) {
      return 'audio';
    }
    
    if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg') ||
        lowerFileName.endsWith('.png') || lowerFileName.endsWith('.gif') ||
        lowerFileName.endsWith('.bmp') || lowerFileName.endsWith('.webp') ||
        lowerFileName.endsWith('.svg')) {
      return 'image';
    }
    
    if (lowerFileName.endsWith('.pdf') || lowerFileName.endsWith('.doc') ||
        lowerFileName.endsWith('.docx') || lowerFileName.endsWith('.txt') ||
        lowerFileName.endsWith('.xls') || lowerFileName.endsWith('.xlsx') ||
        lowerFileName.endsWith('.ppt') || lowerFileName.endsWith('.pptx')) {
      return 'document';
    }
    
    if (lowerFileName.endsWith('.apk')) {
      return 'apk';
    }
    
    if (lowerFileName.endsWith('.zip') || lowerFileName.endsWith('.rar') ||
        lowerFileName.endsWith('.7z') || lowerFileName.endsWith('.tar') ||
        lowerFileName.endsWith('.gz')) {
      return 'archive';
    }
    
    return 'other';
  }

  bool isM3U8Url(String url) {
    return url.toLowerCase().contains('.m3u8');
  }

  String formatFileSize(double bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;

    while (bytes >= 1024 && i < suffixes.length - 1) {
      bytes /= 1024;
      i++;
    }

    return '${bytes.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Widget getFileTypeIcon(String fileName) {
    final fileType = detectFileType(fileName, '');
    
    switch (fileType) {
      case 'video':
        return const Icon(Icons.video_library, size: 40, color: Colors.red);
      case 'audio':
        return const Icon(Icons.music_note, size: 40, color: Colors.purple);
      case 'image':
        return const Icon(Icons.image, size: 40, color: Colors.blue);
      case 'document':
        return const Icon(Icons.description, size: 40, color: Colors.orange);
      case 'apk':
        return const Icon(Icons.android, size: 40, color: Colors.green);
      case 'archive':
        return const Icon(Icons.folder_zip, size: 40, color: Colors.brown);
      default:
        return const Icon(Icons.insert_drive_file, size: 40, color: Colors.grey);
    }
  }

  String? getRemainingTimeFormatted(String taskId) {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null || item.status != DownloadTaskStatus.running) return null;
    
    final tracker = _activeSpeedTrackers[taskId];
    if (tracker == null) return null;
    
    final remainingBytes = item.fileSize - item.downloadedBytes;
    final duration = tracker.getRemainingTime(remainingBytes);
    
    if (duration == null) return null;
    
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m remaining';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s remaining';
    } else {
      return '${duration.inSeconds}s remaining';
    }
  }

  void updateDownloadItem(String taskId, {
    int? progress,
    DownloadTaskStatus? status,
    int? fileSize,
    int? downloadedBytes,
  }) {
    final index = downloadItems.indexWhere((item) => item.taskId == taskId);
    if (index != -1) {
      downloadItems[index] = downloadItems[index].copyWith(
        status: status,
        progress: progress,
        fileSize: fileSize,
        downloadedBytes: downloadedBytes,
      );
      downloadItems.refresh();
    }
  }

  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1f]'), '_')
        .replaceAll('..', '_')
        .trim();
  }

  String _generateUniqueFileName(String fileName) {
    String sanitized = _sanitizeFileName(fileName);
    String uniqueFileName = sanitized;
    int counter = 1;

    while (_fileNameExists(uniqueFileName)) {
      final dotIndex = sanitized.lastIndexOf('.');
      if (dotIndex != -1) {
        uniqueFileName =
            '${sanitized.substring(0, dotIndex)} ($counter)${sanitized.substring(dotIndex)}';
      } else {
        uniqueFileName = '$sanitized ($counter)';
      }
      counter++;
    }

    return uniqueFileName;
  }

  bool _fileNameExists(String fileName) {
    return downloadItems.any((item) => item.fileName == fileName);
  }

  bool _isDuplicateDownload(String url, String fileName, int? fileSize) {
    return downloadItems.any((item) => 
      (item.url == url || item.fileName == fileName) && 
      (item.status == DownloadTaskStatus.running || 
       item.status == DownloadTaskStatus.enqueued ||
       item.status == DownloadTaskStatus.paused) &&
      (fileSize == null || item.fileSize == fileSize));
  }

  Future<void> shareFile(String taskId) async {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return;
    
    final file = File('$_downloadPath/${item.fileName}');
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  Future<void> openFile(String taskId) async {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return;
    
    final file = File('$_downloadPath/${item.fileName}');
    if (await file.exists()) {
      await OpenFilex.open(file.path);
    }
  }

  Map<String, dynamic> getFileInfo(String taskId) {
    final item = downloadItems.firstWhereOrNull((i) => i.taskId == taskId);
    if (item == null) return {};
    
    return {
      'name': item.fileName,
      'size': formatFileSize(item.fileSize.toDouble()),
      'path': '$_downloadPath/${item.fileName}',
      'type': item.fileType ?? 'Unknown',
      'url': item.url,
      'downloadDate': item.startTime.toString(),
      'status': item.status.toString().split('.').last,
      'isMultiThreaded': item.isMultiThreaded,
      'isM3U8': item.isM3U8,
    };
  }

  List<DownloadItem> getFilteredDownloads(String filter) {
    switch (filter) {
      case 'all': return downloadItems.toList();
      case 'video': return downloadItems.where((item) => item.fileType == 'video').toList();
      case 'image': return downloadItems.where((item) => item.fileType == 'image').toList();
      case 'audio': return downloadItems.where((item) => item.fileType == 'audio').toList();
      case 'document': return downloadItems.where((item) => item.fileType == 'document').toList();
      case 'apk': return downloadItems.where((item) => item.fileType == 'apk').toList();
      case 'archive': return downloadItems.where((item) => item.fileType == 'archive').toList();
      case 'complete': return downloadItems.where((item) => item.status == DownloadTaskStatus.complete).toList();
      case 'downloading': return downloadItems.where((item) => 
        item.status == DownloadTaskStatus.running || item.status == DownloadTaskStatus.enqueued).toList();
      default: return downloadItems.toList();
    }
  }

  void toggleSelectionMode() {
    isSelectionMode.value = !isSelectionMode.value;
    if (!isSelectionMode.value) selectedItems.clear();
  }

  void toggleItemSelection(String taskId) {
    if (selectedItems.contains(taskId)) {
      selectedItems.remove(taskId);
    } else {
      selectedItems.add(taskId);
    }
  }

  void selectAllItems() {
    if (selectedItems.length == downloadItems.length) {
      selectedItems.clear();
    } else {
      selectedItems.assignAll(downloadItems.map((item) => item.taskId));
    }
  }

  Future<void> deleteSelectedItems() async {
    for (var taskId in List<String>.from(selectedItems)) {
      await deleteDownload(taskId);
    }
    selectedItems.clear();
    isSelectionMode.value = false;
  }

  Future<void> deleteAllDownloads() async {
    for (var item in List<DownloadItem>.from(downloadItems)) {
      await deleteDownload(item.taskId);
    }
  }

  void sortDownloads(String criteria) {
    switch (criteria) {
      case 'name':
        downloadItems.sort((a, b) => a.fileName.compareTo(b.fileName));
        break;
      case 'date':
        downloadItems.sort((a, b) => b.startTime.compareTo(a.startTime));
        break;
      case 'size':
        downloadItems.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
    }
    downloadItems.refresh();
  }

  void _startPersistenceTimer() {
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveDownloads();
    });
  }

  Future<void> _saveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = downloadItems.map((item) => item.toJson()).toList();
      await prefs.setString('active_downloads', jsonEncode(data));
      debugPrint('✅ Saved ${downloadItems.length} downloads to storage');
    } catch (e) {
      debugPrint('❌ Error saving downloads: $e');
    }
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('active_downloads');
      
      if (savedData != null && savedData.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(savedData);
        final persistedDownloads = jsonList.map((json) => DownloadItem.fromJson(json)).toList();
        
        downloadItems.assignAll(persistedDownloads);
        debugPrint('✅ Loaded ${downloadItems.length} downloads from storage');
        
        for (var item in downloadItems) {
          if (item.status == DownloadTaskStatus.running) {
            final index = downloadItems.indexWhere((i) => i.taskId == item.taskId);
            if (index != -1) {
              downloadItems[index] = item.copyWith(status: DownloadTaskStatus.paused);
            }
          }
        }
        
        downloadItems.refresh();
      } else {
        debugPrint('No persisted downloads found');
      }
    } catch (e) {
      debugPrint('❌ Error loading persisted downloads: $e');
    }
  }

  void _startQueueTimer() {
    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _processDownloadQueue();
    });
  }

  Future<void> _processDownloadQueue() async {
    // CRITICAL: Prevent concurrent queue processing
    if (_isProcessingQueue) {
      debugPrint('⚠️ Queue processing already in progress, skipping...');
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      if (settings.value.wifiOnly && !isWifiConnected.value) {
        debugPrint('📡 WiFi only mode - skipping queue processing');
        return;
      }
      
      if (activeDownloads.length < maxConcurrentDownloads && downloadQueue.isNotEmpty) {
        final availableSlots = maxConcurrentDownloads - activeDownloads.length;
        final tasksToStart = downloadQueue.take(availableSlots).toList();

        for (var taskId in tasksToStart) {
          // CRITICAL: Skip if manually paused
          if (_manuallyPausedItems.contains(taskId)) {
            debugPrint('⏸️ Skipping paused item: $taskId');
            downloadQueue.remove(taskId);
            continue;
          }
          
          // CRITICAL: Skip if pause in progress
          if (_pauseInProgress.contains(taskId)) {
            debugPrint('⏸️ Skipping item with pause in progress: $taskId');
            continue;
          }
          
          // CRITICAL FIX: Skip if already completed
          if (_completedDownloads.contains(taskId)) {
            debugPrint('✅ Skipping completed item: $taskId');
            downloadQueue.remove(taskId);
            continue;
          }
          
          final item = downloadItems.firstWhereOrNull((item) => item.taskId == taskId);
          if (item != null && item.status == DownloadTaskStatus.enqueued) {
            downloadQueue.remove(taskId);
            
            debugPrint('▶️ Processing queue item: ${item.fileName}');
            
            if (item.isM3U8) {
              await downloadM3U8(item.url, item.fileName);
            } else if (settings.value.enableMultiThreading && item.fileSize > 1024 * 1024) {
              await startMultiThreadedDownload(item);
            } else {
              await _startDownload(item);
            }
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDownloadSpeed();
    });
  }

  void _updateDownloadSpeed() {
    double totalSpeed = 0;
    
    for (var entry in _activeSpeedTrackers.entries) {
      final item = downloadItems.firstWhereOrNull((i) => i.taskId == entry.key);
      if (item != null && item.status == DownloadTaskStatus.running) {
        totalSpeed += entry.value.updateSpeed(item.downloadedBytes);
      }
    }
    
    downloadSpeed.value = totalSpeed;
  }

  Future<void> _loadStorageInfo() async {
    double totalSize = 0;
    for (var item in downloadItems) {
      if (item.status == DownloadTaskStatus.complete) {
        final file = File('$_downloadPath/${item.fileName}');
        if (await file.exists()) {
          totalSize += await file.length();
        }
      } else if (item.status == DownloadTaskStatus.running || item.status == DownloadTaskStatus.paused) {
        totalSize += item.downloadedBytes;
      }
    }
    downloadSize.value = totalSize;
  }

  @override
  void onClose() {
    _speedTimer?.cancel();
    _queueTimer?.cancel();
    _persistenceTimer?.cancel();
    _connectivitySubscription?.cancel();
    _batterySubscription?.cancel();

    for (var client in activeDownloads.values) {
      client.close();
    }

    _saveDownloads();
    super.onClose();
  }
  
  Future<bool> _showDownloadPermissionDialog(String url, String fileName) async {
    try {
      if (Get.context == null || !Get.context!.mounted || Get.isDialogOpen == true) {
        debugPrint('Cannot show permission dialog - invalid context or dialog already open');
        return true;
      }
      
      final completer = Completer<bool>();
      
      Get.dialog(
        WillPopScope(
          onWillPop: () async {
            if (!completer.isCompleted) completer.complete(false);
            return true;
          },
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.download, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(child: Text('Download File')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Do you want to download this file?', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('File: $fileName'),
                  const SizedBox(height: 8),
                  Text('From: ${Uri.parse(url).host}', 
                    style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Save to: $_downloadPath', 
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!completer.isCompleted) completer.complete(false);
                  if (Get.isDialogOpen == true) Get.back();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!completer.isCompleted) completer.complete(true);
                  if (Get.isDialogOpen == true) Get.back();
                },
                child: const Text('Download'),
              ),
            ],
          ),
        ),
        barrierDismissible: true,
      ).then((_) {
        if (!completer.isCompleted) completer.complete(false);
      });
      
      return await completer.future;
    } catch (e) {
      debugPrint('Error showing download permission dialog: $e');
      return true;
    }
  }
}