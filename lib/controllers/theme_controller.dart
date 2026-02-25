import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/browser_model.dart';

class ThemeController extends GetxController {
  final RxBool _isDarkMode = false.obs;

  bool get isDarkMode => _isDarkMode.value;

  ThemeData get currentTheme => isDarkMode ? darkTheme : lightTheme;

  // 🔥 Single seed color for whole app (browser style)
  static const Color _seedColor = Color(0xFF1E293B);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      surfaceTint: Colors.transparent, // 🛑 extra safety
    ),

    scaffoldBackgroundColor: Colors.white,

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      surfaceTint: Colors.transparent, // 🛑 extra safety
    ),

    scaffoldBackgroundColor: const Color(0xFF0B0F14),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B0F14),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );

  @override
  void onInit() {
    super.onInit();
    // Don't load theme immediately - wait for browser restoration
  }

  // Call this after BrowserModel.restore() is complete
  void loadThemeFromRestoredSettings() {
    _loadThemeFromSettings();
    Get.changeTheme(currentTheme);
  }

  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _saveThemeToSettings();
    Get.changeTheme(currentTheme);
  }

  void setTheme(bool isDark) {
    _isDarkMode.value = isDark;
    _saveThemeToSettings();
    Get.changeTheme(currentTheme);
  }

  void _loadThemeFromSettings() {
    try {
      final browserModel = Get.find<BrowserModel>();
      _isDarkMode.value = browserModel.getSettings().isDarkMode;
    } catch (_) {
      _isDarkMode.value = false;
    }
  }

  void _saveThemeToSettings() {
    try {
      final browserModel = Get.find<BrowserModel>();
      final settings = browserModel.getSettings();
      settings.isDarkMode = _isDarkMode.value;
      browserModel.updateSettings(settings);
      browserModel.save();
    } catch (_) {}
  }
}
