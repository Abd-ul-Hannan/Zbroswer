import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StateManager {
  static const String _keyLastRoute = 'last_route';
  static const String _keyLastUrl = 'last_url';
  static const String _keyLastTabIndex = 'last_tab_index';
  static const String _keyTimestamp = 'last_save_timestamp';

  /// Saves the current state (route and URL)
  static Future<void> saveState(String route, String? url, {int? tabIndex}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyLastRoute, route);
      await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
      
      if (url != null && url.isNotEmpty) {
        await prefs.setString(_keyLastUrl, url);
      } else {
        await prefs.remove(_keyLastUrl);
      }
      
      if (tabIndex != null) {
        await prefs.setInt(_keyLastTabIndex, tabIndex);
      } else {
        await prefs.remove(_keyLastTabIndex);
      }
      
      debugPrint('✅ StateManager: Saved state - Route: $route, URL: $url, TabIndex: $tabIndex');
    } catch (e) {
      debugPrint('❌ StateManager: Error saving state: $e');
    }
  }

  /// Restores the saved state
  static Future<Map<String, dynamic>> restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final route = prefs.getString(_keyLastRoute);
      final url = prefs.getString(_keyLastUrl);
      final tabIndex = prefs.getInt(_keyLastTabIndex);
      final timestamp = prefs.getString(_keyTimestamp);
      
      debugPrint('📦 StateManager: Restored state - Route: $route, URL: $url, TabIndex: $tabIndex, Timestamp: $timestamp');
      
      return {
        'route': route,
        'url': url,
        'tabIndex': tabIndex,
        'timestamp': timestamp,
      };
    } catch (e) {
      debugPrint('❌ StateManager: Error restoring state: $e');
      return {};
    }
  }

  /// Clears all saved state
  static Future<void> clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_keyLastRoute);
      await prefs.remove(_keyLastUrl);
      await prefs.remove(_keyLastTabIndex);
      await prefs.remove(_keyTimestamp);
      
      debugPrint('🗑️ StateManager: Cleared all state');
    } catch (e) {
      debugPrint('❌ StateManager: Error clearing state: $e');
    }
  }

  /// Checks if there is saved state available
  static Future<bool> hasSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyLastRoute) || prefs.containsKey(_keyLastUrl);
    } catch (e) {
      debugPrint('❌ StateManager: Error checking saved state: $e');
      return false;
    }
  }

  /// Gets only the last saved URL (useful for quick checks)
  static Future<String?> getLastUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastUrl);
    } catch (e) {
      debugPrint('❌ StateManager: Error getting last URL: $e');
      return null;
    }
  }

  /// Gets only the last saved route
  static Future<String?> getLastRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLastRoute);
    } catch (e) {
      debugPrint('❌ StateManager: Error getting last route: $e');
      return null;
    }
  }
}