import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:zbrowser/utils/util.dart';
import 'package:window_manager_plus/window_manager_plus.dart';
import 'package:get/get.dart';
import '../main.dart';
import 'web_archive_model.dart';
import 'window_model.dart';
import 'favorite_model.dart';
import 'search_engine_model.dart';
import 'package:collection/collection.dart';

class BrowserSettings {
  SearchEngineModel searchEngine;
  bool homePageEnabled;
  String customUrlHomePage;
  bool debuggingEnabled;
  bool isDarkMode;

  BrowserSettings({
    this.searchEngine = GoogleSearchEngine,
    this.homePageEnabled = false,
    this.customUrlHomePage = "",
    this.debuggingEnabled = false,
    this.isDarkMode = false,
  });

  BrowserSettings copy() {
    return BrowserSettings(
      searchEngine: searchEngine,
      homePageEnabled: homePageEnabled,
      customUrlHomePage: customUrlHomePage,
      debuggingEnabled: debuggingEnabled,
      isDarkMode: isDarkMode,
    );
  }

  static BrowserSettings? fromMap(Map<String, dynamic>? map) {
    return map != null
        ? BrowserSettings(
            searchEngine: SearchEngines[map["searchEngineIndex"]],
            homePageEnabled: map["homePageEnabled"],
            customUrlHomePage: map["customUrlHomePage"],
            debuggingEnabled: map["debuggingEnabled"],
            isDarkMode: map["isDarkMode"] ?? false,
          )
        : null;
  }

  Map<String, dynamic> toMap() {
    return {
      "searchEngineIndex": SearchEngines.indexOf(searchEngine),
      "homePageEnabled": homePageEnabled,
      "customUrlHomePage": customUrlHomePage,
      "debuggingEnabled": debuggingEnabled,
      "isDarkMode": isDarkMode,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => toMap().toString();
}

class BrowserModel extends GetxController {
  // Reactive observable lists
  final RxList<FavoriteModel> favorites = <FavoriteModel>[].obs;
  final RxMap<String, WebArchiveModel> webArchives = <String, WebArchiveModel>{}.obs;
  
  // Settings as Rx for reactivity
  final Rx<BrowserSettings> _settings = BrowserSettings().obs;
  
  // Observable flags
  final RxBool showTabScroller = false.obs;
  final RxBool _isRestored = false.obs;

  bool get isRestored => _isRestored.value;
  set isRestored(bool value) => _isRestored.value = value;

  BrowserSettings getSettings() => _settings.value.copy();
  
  void updateSettings(BrowserSettings settings) {
    _settings.value = settings;
    update(); // Trigger UI update immediately
    save(); // Save to database
  }

  BrowserModel();

  @override
  void onInit() {
    super.onInit();
    // Any initialization logic here if needed
  }

  Future<void> openWindow(WindowModel? windowModel) async {
    if (Util.isMobile()) return;

    try {
      final window = await WindowManagerPlus.createWindow(
        windowModel != null ? [windowModel.id] : null,
      );
      
      if (window != null) {
        debugPrint("✅ Window created: $window");
      } else {
        debugPrint("❌ Cannot create window");
      }
    } catch (e) {
      debugPrint('Error opening window: $e');
    }
  }

  Future<void> removeWindow(WindowModel window) async {
    try {
      await window.removeInfo();
    } catch (e) {
      debugPrint('Error removing window: $e');
    }
  }

  Future<void> removeAllWindows() async {
    try {
      final count = await db?.rawDelete('DELETE FROM windows');
      if ((count == null || count == 0) && kDebugMode) {
        debugPrint("Cannot delete windows");
      }
    } catch (e) {
      debugPrint('Error removing all windows: $e');
    }
  }

  // --- Favorites Management ---
  bool containsFavorite(FavoriteModel favorite) {
    return favorites.contains(favorite) ||
        favorites.firstWhereOrNull((element) => element.url == favorite.url) != null;
  }

  void addFavorite(FavoriteModel favorite) {
    if (!containsFavorite(favorite)) {
      favorites.add(favorite);
      save();
    }
  }

  void addFavorites(List<FavoriteModel> favoritesList) {
    for (var fav in favoritesList) {
      if (!containsFavorite(fav)) {
        favorites.add(fav);
      }
    }
    save();
  }

  void clearFavorites() {
    favorites.clear();
    save();
  }

  void removeFavorite(FavoriteModel favorite) {
    if (!favorites.remove(favorite)) {
      var favToRemove = favorites
          .firstWhereOrNull((element) => element.url == favorite.url);
      if (favToRemove != null) {
        favorites.remove(favToRemove);
      }
    }
    save();
  }

  // --- Web Archives Management ---
  void addWebArchive(String url, WebArchiveModel webArchiveModel) {
    webArchives.putIfAbsent(url, () => webArchiveModel);
    save();
  }

  void addWebArchives(Map<String, WebArchiveModel> webArchivesList) {
    webArchives.addAll(webArchivesList);
    save();
  }

  void removeWebArchive(WebArchiveModel webArchive) {
    try {
      final path = webArchive.path;
      if (path != null) {
        final webArchiveFile = File(path);
        if (webArchiveFile.existsSync()) {
          webArchiveFile.deleteSync();
        }
        webArchives.remove(webArchive.url.toString());
        save();
      }
    } catch (e) {
      debugPrint('Error removing web archive: $e');
    }
  }

  void clearWebArchives() {
    try {
      final archivesToRemove = <String>[];
      
      webArchives.forEach((key, webArchive) {
        final path = webArchive.path;
        if (path != null) {
          final webArchiveFile = File(path);
          try {
            if (webArchiveFile.existsSync()) {
              webArchiveFile.deleteSync();
            }
          } catch (e) {
            debugPrint('Error deleting archive file: $e');
          }
          archivesToRemove.add(key);
        }
      });
      
      for (var key in archivesToRemove) {
        webArchives.remove(key);
      }
      
      save();
    } catch (e) {
      debugPrint('Error clearing web archives: $e');
    }
  }

  // --- Windows Management ---
  Future<List<WindowModel>> getWindows() async {
    final List<WindowModel> windows = [];
    
    try {
      final windowsMap = await db?.rawQuery('SELECT * FROM windows');
      if (windowsMap == null) return windows;

      for (final w in windowsMap) {
        try {
          final wId = w['id'] as String;
          if (wId.startsWith('window_')) {
            final source = w['json'] as String;
            Map<String, dynamic> wBrowserData = json.decode(source);
            final windowModel = WindowModel.fromMap(wBrowserData);
            if (windowModel != null) {
              windows.add(windowModel);
            }
          }
        } catch (e) {
          debugPrint('Error loading window: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting windows: $e');
    }

    return windows;
  }

  // --- Persistence ---
  DateTime _lastTrySave = DateTime.now();
  Timer? _timerSave;

  Future<void> save() async {
    _timerSave?.cancel();
    // EXTREME: 2s debounce
    if (DateTime.now().difference(_lastTrySave) >= const Duration(seconds: 2)) {
      _lastTrySave = DateTime.now();
      await flush();
    } else {
      _lastTrySave = DateTime.now();
      _timerSave = Timer(const Duration(seconds: 2), save);
    }
  }

  Future<void> flush() async {
    try {
      final data = json.encode(toJson());
      final exists = await db?.rawQuery('SELECT 1 FROM browser WHERE id = 1 LIMIT 1');
      if (exists == null || exists.isEmpty) {
        await db?.rawInsert('INSERT INTO browser(id, json) VALUES(1, ?)', [data]);
      } else {
        await db?.rawUpdate('UPDATE browser SET json = ? WHERE id = 1', [data]);
      }
    } catch (e) {}
  }

  Future<void> restore() async {
    try {
      final browsers = await db?.rawQuery('SELECT * FROM browser WHERE id = ?', [1]);
      
      if (browsers == null || browsers.isEmpty) {
        debugPrint('No browser data to restore');
        return;
      }

      final browser = browsers[0];
      final browserData = json.decode(browser['json'] as String) as Map<String, dynamic>;

      // Clear existing data
      clearFavorites();
      clearWebArchives();

      // Restore favorites
      final List<Map<String, dynamic>> favoritesList =
          browserData["favorites"]?.cast<Map<String, dynamic>>() ?? [];
      final List<FavoriteModel> restoredFavorites =
          favoritesList.map((e) => FavoriteModel.fromMap(e)!).toList();

      // Restore web archives
      final Map<String, dynamic> webArchivesMap =
          browserData["webArchives"]?.cast<String, dynamic>() ?? {};
      final Map<String, WebArchiveModel> restoredWebArchives = webArchivesMap.map(
        (key, value) => MapEntry(
          key,
          WebArchiveModel.fromMap(value?.cast<String, dynamic>())!,
        ),
      );

      // Restore settings
      final BrowserSettings restoredSettings = BrowserSettings.fromMap(
            browserData["settings"]?.cast<String, dynamic>(),
          ) ??
          BrowserSettings();

      // Apply restored data
      addFavorites(restoredFavorites);
      addWebArchives(restoredWebArchives);
      updateSettings(restoredSettings);

      debugPrint('✅ Browser data restored successfully');
    } catch (e) {
      debugPrint('❌ Error restoring browser data: $e');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      "favorites": favorites.map((e) => e.toMap()).toList(),
      "webArchives": webArchives.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      "settings": _settings.value.toMap(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() => toMap().toString();

  @override
  void onClose() {
    _timerSave?.cancel();
    super.onClose();
  }
}