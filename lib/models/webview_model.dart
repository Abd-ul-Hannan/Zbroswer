import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class WebViewModel extends GetxController {
  // --- Reactive Variables (.obs) ---
  final Rxn<int> _tabIndex = Rxn<int>();
  final Rxn<WebUri> _url = Rxn<WebUri>();
  final Rxn<String> _title = Rxn<String>();
  final Rxn<Favicon> _favicon = Rxn<Favicon>();
  final RxDouble _progress = 0.0.obs;
  final RxBool _loaded = false.obs;
  final RxBool _isDesktopMode = false.obs;
  final RxBool _isIncognitoMode = false.obs;
  final RxBool _isSecure = false.obs;
  
  // Lists as RxLists
  final RxList<Widget> javaScriptConsoleResults = <Widget>[].obs;
  final RxList<String> javaScriptConsoleHistory = <String>[].obs;
  final RxList<LoadedResource> loadedResources = <LoadedResource>[].obs;

  // --- Non-Reactive Variables (Internal Logic) ---
  int? windowId;
  final Rxn<InAppWebViewSettings> _settings = Rxn<InAppWebViewSettings>();
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  FindInteractionController? findInteractionController;
  Uint8List? screenshot;
  bool needsToCompleteInitialLoad;
  final DateTime _createdTime;
  DateTime _lastOpenedTime;

  final keepAlive = InAppWebViewKeepAlive();

  WebViewModel({
    int? tabIndex,
    WebUri? url,
    String? title,
    Favicon? favicon,
    double progress = 0.0,
    bool loaded = false,
    bool isDesktopMode = false,
    bool isIncognitoMode = false,
    List<Widget>? javaScriptConsoleResultsData,
    List<String>? javaScriptConsoleHistoryData,
    List<LoadedResource>? loadedResourcesData,
    bool isSecure = false,
    DateTime? createdTime,
    DateTime? lastOpenedTime,
    this.windowId,
    InAppWebViewSettings? settings,
    this.webViewController,
    this.pullToRefreshController,
    this.findInteractionController,
    this.needsToCompleteInitialLoad = true,
  })  : _createdTime = createdTime ?? DateTime.now(),
        _lastOpenedTime = lastOpenedTime ?? DateTime.now() {
    // Initializing reactive values
    _tabIndex.value = tabIndex;
    _url.value = url;
    _title.value = title;
    _favicon.value = favicon;
    _progress.value = progress;
    _loaded.value = loaded;
    _isDesktopMode.value = isDesktopMode;
    _isIncognitoMode.value = isIncognitoMode;
    _isSecure.value = isSecure;

    if (javaScriptConsoleResultsData != null) {
      javaScriptConsoleResults.addAll(javaScriptConsoleResultsData);
    }
    if (javaScriptConsoleHistoryData != null) {
      javaScriptConsoleHistory.addAll(javaScriptConsoleHistoryData);
    }
    if (loadedResourcesData != null) {
      loadedResources.addAll(loadedResourcesData);
    }

    _settings.value = settings ?? InAppWebViewSettings();
  }

  // --- Getters & Setters (Reactive) ---
  int? get tabIndex => _tabIndex.value;
  set tabIndex(int? value) => _tabIndex.value = value;

  Rx<WebUri?> get urlRx => _url;
  WebUri? get url => _url.value;
  set url(WebUri? value) => _url.value = value;

  Rx<String?> get titleRx => _title;
  String? get title => _title.value;
  set title(String? value) => _title.value = value;

  Rx<Favicon?> get faviconRx => _favicon;
  Favicon? get favicon => _favicon.value;
  set favicon(Favicon? value) => _favicon.value = value;

  RxDouble get progressRx => _progress;
  double get progress => _progress.value;
  set progress(double value) => _progress.value = value;

  RxBool get loadedRx => _loaded;
  bool get loaded => _loaded.value;
  set loaded(bool value) => _loaded.value = value;

  bool get isDesktopMode => _isDesktopMode.value;
  set isDesktopMode(bool value) => _isDesktopMode.value = value;

  bool get isIncognitoMode => _isIncognitoMode.value;
  set isIncognitoMode(bool value) => _isIncognitoMode.value = value;

  bool get isSecure => _isSecure.value;
  set isSecure(bool value) => _isSecure.value = value;

  InAppWebViewSettings? get settings => _settings.value;
  set settings(InAppWebViewSettings? value) => _settings.value = value;

  DateTime get createdTime => _createdTime;
  DateTime get lastOpenedTime => _lastOpenedTime;
  set lastOpenedTime(DateTime value) => _lastOpenedTime = value;

  // --- Helper Methods ---
  void setJavaScriptConsoleResults(List<Widget> value) {
    javaScriptConsoleResults.assignAll(value);
  }

  void addJavaScriptConsoleResults(Widget value) {
    javaScriptConsoleResults.add(value);
  }

  void setLoadedResources(List<LoadedResource> value) {
    loadedResources.assignAll(value);
  }

  void addLoadedResources(LoadedResource value) {
    loadedResources.add(value);
  }

  void setJavaScriptConsoleHistory(List<String> value) {
    javaScriptConsoleHistory.assignAll(value);
  }

  void addJavaScriptConsoleHistory(String value) {
    javaScriptConsoleHistory.add(value);
  }

  void clearJavaScriptConsoleHistory() {
    javaScriptConsoleHistory.clear();
  }

  // --- Data Sync ---
  void updateWithValue(WebViewModel other) {
    tabIndex = other.tabIndex;
    url = other.url;
    title = other.title;
    favicon = other.favicon;
    progress = other.progress;
    loaded = other.loaded;
    isDesktopMode = other.isDesktopMode;
    isIncognitoMode = other.isIncognitoMode;
    isSecure = other.isSecure;
    javaScriptConsoleResults.assignAll(other.javaScriptConsoleResults);
    javaScriptConsoleHistory.assignAll(other.javaScriptConsoleHistory);
    loadedResources.assignAll(other.loadedResources);
  }

  Map<String, dynamic> toMap() {
    return {
      "tabIndex": tabIndex,
      "url": url?.toString(),
      "title": title,
      "favicon": favicon?.toMap(),
      "progress": progress,
      "isDesktopMode": isDesktopMode,
      "isIncognitoMode": isIncognitoMode,
      "isSecure": isSecure,
      "settings": settings?.toMap(),
      "createdTime": _createdTime.toIso8601String(),
      "lastOpenedTime": _lastOpenedTime.toIso8601String(),
    };
  }

  static WebViewModel? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    Favicon? favicon;
    if (map["favicon"] != null) {
      final fav = map["favicon"] as Map<String, dynamic>;
      favicon = Favicon(
        url: WebUri(fav["url"]),
        rel: fav["rel"],
        width: fav["width"],
        height: fav["height"],
      );
    }

    return WebViewModel(
      tabIndex: map["tabIndex"],
      url: map["url"] != null ? WebUri(map["url"]) : null,
      title: map["title"],
      favicon: favicon,
      progress: (map["progress"] is num) ? (map["progress"] as num).toDouble() : 0.0,
      loaded: map["loaded"] ?? false,
      isDesktopMode: map["isDesktopMode"] ?? false,
      isIncognitoMode: map["isIncognitoMode"] ?? false,
      isSecure: map["isSecure"] ?? false,
      createdTime: map["createdTime"] != null ? DateTime.tryParse(map["createdTime"]) : null,
      lastOpenedTime: map["lastOpenedTime"] != null ? DateTime.tryParse(map["lastOpenedTime"]) : null,
    );
  }

  @override
  void onClose() {
    // Cleanup
    webViewController = null;
    pullToRefreshController = null;
    findInteractionController = null;
    screenshot = null;
    super.onClose();
  }
}