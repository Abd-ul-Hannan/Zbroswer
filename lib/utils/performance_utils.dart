import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show FrameTiming;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PerformanceUtils {
  static const int _frameThreshold = 16; // 60fps = ~16ms per frame
  
  // Debounce
  static final Map<String, Timer> _debounceTimers = {};
  
  /// Debounce function calls with optional key for multiple debounce instances
  static void debounce(
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 300),
    String key = 'default',
  }) {
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }
  
  // Throttle
  static final Map<String, DateTime> _lastThrottleTimes = {};
  
  /// Throttle function calls with optional key for multiple throttle instances
  static bool throttle({
    Duration interval = const Duration(milliseconds: 100),
    String key = 'default',
  }) {
    final now = DateTime.now();
    final lastTime = _lastThrottleTimes[key];
    
    if (lastTime == null || now.difference(lastTime) >= interval) {
      _lastThrottleTimes[key] = now;
      return true;
    }
    return false;
  }
  
  /// Execute heavy operations in next frame to prevent blocking
  static void executeInNextFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in executeInNextFrame: $e');
      }
    });
  }
  
  /// Execute after multiple frames for heavy operations
  static void executeAfterFrames(VoidCallback callback, {int frames = 2}) {
    int frameCount = 0;
    
    void frameCallback(Duration timestamp) {
      frameCount++;
      if (frameCount >= frames) {
        try {
          callback();
        } catch (e) {
          debugPrint('Error in executeAfterFrames: $e');
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback(frameCallback);
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback(frameCallback);
  }
  
  /// Break heavy operations into chunks
  static Future<void> executeInChunks<T>(
    List<T> items,
    Function(T) processor, {
    int chunkSize = 10,
    Duration delay = const Duration(milliseconds: 1),
    Function(int processed, int total)? onProgress,
  }) async {
    for (int i = 0; i < items.length; i += chunkSize) {
      final chunk = items.skip(i).take(chunkSize);
      
      try {
        for (final item in chunk) {
          processor(item);
        }
      } catch (e) {
        debugPrint('Error processing chunk at index $i: $e');
      }
      
      // Report progress
      onProgress?.call(i + chunk.length, items.length);
      
      // Yield control back to the UI thread
      if (i + chunkSize < items.length) {
        await Future.delayed(delay);
      }
    }
  }
  
  /// Compute heavy operations in isolate for CPU-intensive tasks
  static Future<R> computeInIsolate<T, R>(
    ComputeCallback<T, R> callback,
    T message, {
    String? debugLabel,
  }) async {
    try {
      return await compute(callback, message, debugLabel: debugLabel);
    } catch (e) {
      debugPrint('Error in computeInIsolate: $e');
      rethrow;
    }
  }
  
  /// Monitor frame rendering performance
  static TimingsCallback? _frameCallback;
  
  static void monitorFramePerformance({
    int threshold = _frameThreshold,
    bool verbose = false,
  }) {
    if (!kDebugMode) return;
    
    // Remove existing callback if any
    if (_frameCallback != null) {
      WidgetsBinding.instance.removeTimingsCallback(_frameCallback!);
    }
    
    _frameCallback = (List<FrameTiming> timings) {
      for (final timing in timings) {
        final frameDuration = timing.totalSpan.inMilliseconds;
        
        if (frameDuration > threshold) {
          debugPrint('⚠️ Slow frame: ${frameDuration}ms (threshold: ${threshold}ms)');
          
          if (verbose) {
            debugPrint('  Build: ${timing.buildDuration.inMilliseconds}ms');
            debugPrint('  Raster: ${timing.rasterDuration.inMilliseconds}ms');
          }
        }
      }
    };
    
    WidgetsBinding.instance.addTimingsCallback(_frameCallback!);
  }
  
  /// Stop monitoring frame performance
  static void stopMonitoringFramePerformance() {
    if (_frameCallback != null) {
      WidgetsBinding.instance.removeTimingsCallback(_frameCallback!);
      _frameCallback = null;
    }
  }
  
  /// Get current FPS (approximate)
  static double getCurrentFPS() {
    // This is a simplified approximation
    final binding = WidgetsBinding.instance;
    if (binding.hasScheduledFrame) {
      return 60.0; // Assume 60 FPS if frames are scheduled
    }
    return 0.0;
  }
  
  /// Memory usage info (for debugging)
  static void logMemoryUsage() {
    if (!kDebugMode) return;
    
    try {
      // This is platform-specific and may not work on all platforms
      debugPrint('Memory usage logging is platform-specific');
    } catch (e) {
      debugPrint('Error logging memory usage: $e');
    }
  }
  
  /// Cleanup resources
  static void dispose() {
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    
    // Clear throttle times
    _lastThrottleTimes.clear();
    
    // Stop frame monitoring
    stopMonitoringFramePerformance();
  }
  
  /// Cleanup specific debounce/throttle instances
  static void disposeKey(String key) {
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
    _lastThrottleTimes.remove(key);
  }
}

/// Mixin for widgets that need performance optimizations
mixin PerformanceOptimizedWidget {
  /// Schedule update in next frame
  void scheduleUpdate(VoidCallback callback) {
    PerformanceUtils.executeInNextFrame(callback);
  }
  
  /// Schedule update after multiple frames
  void scheduleDelayedUpdate(VoidCallback callback, {int frames = 2}) {
    PerformanceUtils.executeAfterFrames(callback, frames: frames);
  }
  
  /// Debounced update with optional key
  void debouncedUpdate(
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 300),
    String key = 'default',
  }) {
    PerformanceUtils.debounce(callback, delay: delay, key: key);
  }
  
  /// Check if update should be throttled
  bool shouldThrottleUpdate({
    Duration interval = const Duration(milliseconds: 100),
    String key = 'default',
  }) {
    return PerformanceUtils.throttle(interval: interval, key: key);
  }
  
  /// Execute heavy operation in chunks
  Future<void> executeHeavyOperation<T>(
    List<T> items,
    Function(T) processor, {
    int chunkSize = 10,
    Function(int, int)? onProgress,
  }) {
    return PerformanceUtils.executeInChunks(
      items,
      processor,
      chunkSize: chunkSize,
      onProgress: onProgress,
    );
  }
}

/// Extension for List to add chunked processing
extension PerformanceListExtension<T> on List<T> {
  Future<void> processInChunks(
    Function(T) processor, {
    int chunkSize = 10,
    Duration delay = const Duration(milliseconds: 1),
  }) {
    return PerformanceUtils.executeInChunks(
      this,
      processor,
      chunkSize: chunkSize,
      delay: delay,
    );
  }
}