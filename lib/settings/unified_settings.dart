import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/utils/util.dart';
import '../models/window_model.dart';
import '../dialogs+action/multiselect_dialog.dart';

class UnifiedSettings extends StatelessWidget {
  const UnifiedSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      UnifiedSettingsController(),
      tag: 'unified_settings',
      permanent: false,
    );

    return GetBuilder<WindowModel>(
      builder: (windowModel) {
        if (windowModel.webViewTabs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tab, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text("No WebView tab open", style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text("Open a tab to configure WebView settings", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return GetBuilder<UnifiedSettingsController>(
          tag: 'unified_settings',
          builder: (ctrl) {
            if (ctrl.currentWebViewModel == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    SizedBox(height: 16),
                    Text("No current tab available", style: TextStyle(fontSize: 18, color: Colors.orange)),
                  ],
                ),
              );
            }

            return ListView(children: ctrl.buildSettings(context));
          },
        );
      },
    );
  }
}

class UnifiedSettingsController extends GetxController {
  WindowModel get windowModel => Get.find<WindowModel>();

  WebViewModel? get currentWebViewModel {
    try {
      final currentTab = windowModel.getCurrentTab();
      return currentTab?.webViewModel;
    } catch (e) {
      return null;
    }
  }

  InAppWebViewController? get webViewController => currentWebViewModel?.webViewController;

  Future<void> _applySettings() async {
    final webViewModel = currentWebViewModel;
    if (webViewModel == null) return;

    try {
      await webViewController?.setSettings(
          settings: webViewModel.settings ?? InAppWebViewSettings());
      final newSettings = await webViewController?.getSettings();
      if (newSettings != null) {
        webViewModel.settings = newSettings;
      }
      windowModel.saveInfo();
      update();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to apply settings: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  List<Widget> buildSettings(BuildContext context) {
    final isAndroid = Util.isAndroid();
    final isIOS = Util.isIOS();
    final isMobile = Util.isMobile();

    List<Widget> widgets = [];

    // Platform header with icon
    widgets.add(
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isAndroid ? Icons.android : isIOS ? Icons.phone_iphone : Icons.computer,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAndroid ? "Android WebView Settings" : isIOS ? "iOS WebView Settings" : "Platform WebView Settings",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMobile ? "Configure mobile-specific WebView behavior" : "Configure desktop WebView behavior",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Platform-specific settings
    if (isAndroid) {
      widgets.addAll(_buildAndroidSettings(context));
    } else if (isIOS) {
      widgets.addAll(_buildIOSSettings(context));
    } else {
      // Desktop or unsupported platform
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.info_outline, size: 48, color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  "Platform-specific settings are available on mobile devices",
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  List<Widget> _buildAndroidSettings(BuildContext context) {
    return [
      _buildSectionHeader("Display & Zoom", Icons.zoom_in),
      _buildNumberField('text_zoom', 'Text Zoom', 'Sets the text zoom of the page in percent.',
          () => currentWebViewModel?.settings?.textZoom ?? 100,
          (val) => currentWebViewModel!.settings!.textZoom = val),
      _buildSwitch('zoom_controls', 'Built In Zoom Controls',
          'Sets whether the WebView should use its built-in zoom mechanisms.',
          () => currentWebViewModel?.settings?.builtInZoomControls ?? false,
          (v) => currentWebViewModel!.settings!.builtInZoomControls = v),
      _buildSwitch('display_zoom', 'Display Zoom Controls',
          'Sets whether the WebView should display on-screen zoom controls.',
          () => currentWebViewModel?.settings?.displayZoomControls ?? false,
          (v) => currentWebViewModel!.settings!.displayZoomControls = v),
      _buildSwitch('overview_mode', 'Load With Overview Mode',
          'Sets whether the WebView loads pages in overview mode.',
          () => currentWebViewModel?.settings?.loadWithOverviewMode ?? false,
          (v) => currentWebViewModel!.settings!.loadWithOverviewMode = v),

      _buildSectionHeader("Storage & Cache", Icons.storage),
      _buildSwitch('clear_cache', 'Clear Session Cache',
          'Clear the session cookie cache before opening new windows.',
          () => currentWebViewModel?.settings?.clearSessionCache ?? false,
          (v) => currentWebViewModel!.settings!.clearSessionCache = v),
      _buildSwitch('database', 'Database Storage API',
          'Enable the Database storage API.',
          () => currentWebViewModel?.settings?.databaseEnabled ?? true,
          (v) => currentWebViewModel!.settings!.databaseEnabled = v),
      _buildSwitch('dom_storage', 'DOM Storage API',
          'Enable the DOM storage API.',
          () => currentWebViewModel?.settings?.domStorageEnabled ?? true,
          (v) => currentWebViewModel!.settings!.domStorageEnabled = v),
      _buildDropdown<CacheMode>('cache_mode', 'Cache Mode',
          'Overrides the way the cache is used.',
          CacheMode.values.toList(),
          () => currentWebViewModel?.settings?.cacheMode,
          (v) => currentWebViewModel!.settings!.cacheMode = v),
      _buildTextField('cache_path', 'App Cache Path',
          'Sets the path to the Application Caches files.',
          () => currentWebViewModel?.settings?.appCachePath ?? '',
          (v) => currentWebViewModel!.settings!.appCachePath = v.trim()),

      _buildSectionHeader("Network & Security", Icons.security),
      _buildDropdown<MixedContentMode>('mixed_content', 'Mixed Content Mode',
          'Configure behavior when secure origins load insecure resources.',
          MixedContentMode.values.toList(),
          () => currentWebViewModel?.settings?.mixedContentMode,
          (v) => currentWebViewModel!.settings!.mixedContentMode = v),
      _buildSwitch('content_access', 'Allow Content Access',
          'Enable content URL access within WebView.',
          () => currentWebViewModel?.settings?.allowContentAccess ?? true,
          (v) => currentWebViewModel!.settings!.allowContentAccess = v),
      _buildSwitch('file_access', 'Allow File Access',
          'Enable file access within WebView.',
          () => currentWebViewModel?.settings?.allowFileAccess ?? true,
          (v) => currentWebViewModel!.settings!.allowFileAccess = v),
      _buildSwitch('block_image', 'Block Network Images',
          'Prevent loading image resources from the network.',
          () => currentWebViewModel?.settings?.blockNetworkImage ?? false,
          (v) => currentWebViewModel!.settings!.blockNetworkImage = v),
      _buildSwitch('block_network', 'Block Network Loads',
          'Prevent loading resources from the network.',
          () => currentWebViewModel?.settings?.blockNetworkLoads ?? false,
          (v) => currentWebViewModel!.settings!.blockNetworkLoads = v),
      _buildSwitch('geolocation', 'Geolocation Enabled',
          'Enable Geolocation API.',
          () => currentWebViewModel?.settings?.geolocationEnabled ?? true,
          (v) => currentWebViewModel!.settings!.geolocationEnabled = v),

      _buildSectionHeader("Layout & Rendering", Icons.web),
      _buildSwitch('viewport', 'Use Wide View Port',
          'Enable support for the viewport HTML meta tag.',
          () => currentWebViewModel?.settings?.useWideViewPort ?? true,
          (v) => currentWebViewModel!.settings!.useWideViewPort = v),
      _buildDropdown<LayoutAlgorithm>('layout_algo', 'Layout Algorithm',
          'Sets the underlying layout algorithm.',
          LayoutAlgorithm.values.toList(),
          () => currentWebViewModel?.settings?.layoutAlgorithm,
          (v) => currentWebViewModel!.settings!.layoutAlgorithm = v),
      _buildSwitch('hardware_acc', 'Hardware Acceleration',
          'Enable hardware acceleration for better performance.',
          () => currentWebViewModel?.settings?.hardwareAcceleration ?? true,
          (v) => currentWebViewModel!.settings!.hardwareAcceleration = v),
      _buildDropdown<ForceDark>('force_dark', 'Force Dark Mode',
          'Set the force dark mode for this WebView.',
          ForceDark.values.toList(),
          () => currentWebViewModel?.settings?.forceDark,
          (v) => currentWebViewModel!.settings!.forceDark = v),

      _buildSectionHeader("Typography", Icons.text_fields),
      _buildTextField('cursive_font', 'Cursive Font Family',
          'Sets the cursive font family name.',
          () => currentWebViewModel?.settings?.cursiveFontFamily ?? 'cursive',
          (v) => currentWebViewModel!.settings!.cursiveFontFamily = v),
      _buildTextField('fantasy_font', 'Fantasy Font Family',
          'Sets the fantasy font family name.',
          () => currentWebViewModel?.settings?.fantasyFontFamily ?? 'fantasy',
          (v) => currentWebViewModel!.settings!.fantasyFontFamily = v),
      _buildTextField('fixed_font', 'Fixed Font Family',
          'Sets the fixed font family name.',
          () => currentWebViewModel?.settings?.fixedFontFamily ?? 'monospace',
          (v) => currentWebViewModel!.settings!.fixedFontFamily = v),
      _buildNumberField('fixed_font_size', 'Default Fixed Font Size',
          'Sets the default fixed font size.',
          () => currentWebViewModel?.settings?.defaultFixedFontSize ?? 16,
          (val) => currentWebViewModel!.settings!.defaultFixedFontSize = val),
      _buildNumberField('default_font_size', 'Default Font Size',
          'Sets the default font size.',
          () => currentWebViewModel?.settings?.defaultFontSize ?? 16,
          (val) => currentWebViewModel!.settings!.defaultFontSize = val),
      _buildTextField('text_encoding', 'Default Text Encoding',
          'Sets the default text encoding for HTML pages.',
          () => currentWebViewModel?.settings?.defaultTextEncodingName ?? 'UTF-8',
          (v) => currentWebViewModel!.settings!.defaultTextEncodingName = v),

      _buildSectionHeader("Advanced", Icons.settings_applications),
      _buildSwitch('multi_windows', 'Support Multiple Windows',
          'Enable support for multiple windows.',
          () => currentWebViewModel?.settings?.supportMultipleWindows ?? false,
          (v) => currentWebViewModel!.settings!.supportMultipleWindows = v),
      _buildDropdown<ActionModeMenuItem>('action_menu', 'Disabled Action Menu Items',
          'Disable specific action mode menu items.',
          ActionModeMenuItem.values.toList(),
          () => currentWebViewModel?.settings?.disabledActionModeMenuItems,
          (v) => currentWebViewModel!.settings!.disabledActionModeMenuItems = v),
      _buildColorPicker(context, 'scrollbar_color', 'Scrollbar Thumb Color',
          'Sets the vertical scrollbar thumb color.',
          () => currentWebViewModel?.settings?.verticalScrollbarThumbColor ?? Colors.grey,
          (color) => currentWebViewModel!.settings!.verticalScrollbarThumbColor = color),
    ];
  }

  List<Widget> _buildIOSSettings(BuildContext context) {
    return [
      _buildSectionHeader("Scrolling & Gestures", Icons.touch_app),
      _buildSwitch('over_scroll', 'Disallow Over Scroll',
          'Prevent bouncing when scrolling reaches content edges.',
          () => currentWebViewModel?.settings?.disallowOverScroll ?? false,
          (v) => currentWebViewModel!.settings!.disallowOverScroll = v),
      _buildSwitch('back_forward_gesture', 'Back/Forward Navigation Gestures',
          'Enable horizontal swipe gestures for navigation.',
          () => currentWebViewModel?.settings?.allowsBackForwardNavigationGestures ?? true,
          (v) => currentWebViewModel!.settings!.allowsBackForwardNavigationGestures = v),
      _buildSwitch('bounce_vertical', 'Always Bounce Vertical',
          'Enable bouncing when vertical scrolling reaches the end.',
          () => currentWebViewModel?.settings?.alwaysBounceVertical ?? false,
          (v) => currentWebViewModel!.settings!.alwaysBounceVertical = v),
      _buildSwitch('bounce_horizontal', 'Always Bounce Horizontal',
          'Enable bouncing when horizontal scrolling reaches the end.',
          () => currentWebViewModel?.settings?.alwaysBounceHorizontal ?? false,
          (v) => currentWebViewModel!.settings!.alwaysBounceHorizontal = v),
      _buildSwitch('scroll_top', 'Scrolls To Top',
          'Enable the scroll-to-top gesture.',
          () => currentWebViewModel?.settings?.scrollsToTop ?? true,
          (v) => currentWebViewModel!.settings!.scrollsToTop = v),
      _buildSwitch('paging', 'Paging Enabled',
          'Enable paging for the scroll view.',
          () => currentWebViewModel?.settings?.isPagingEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isPagingEnabled = v),
      _buildSwitch('directional_lock', 'Directional Lock Enabled',
          'Disable scrolling in a particular direction.',
          () => currentWebViewModel?.settings?.isDirectionalLockEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isDirectionalLockEnabled = v),
      _buildDropdown<ScrollViewDecelerationRate>('deceleration', 'Deceleration Rate',
          'Rate of deceleration after lifting finger.',
          ScrollViewDecelerationRate.values.toList(),
          () => currentWebViewModel?.settings?.decelerationRate,
          (v) => currentWebViewModel!.settings!.decelerationRate = v),

      _buildSectionHeader("Zoom & Scale", Icons.zoom_in),
      _buildSwitch('viewport_scale', 'Enable Viewport Scale',
          'Allow viewport meta tag to control user scaling.',
          () => currentWebViewModel?.settings?.enableViewportScale ?? false,
          (v) => currentWebViewModel!.settings!.enableViewportScale = v),
      _buildSwitch('viewport_limits', 'Ignores Viewport Scale Limits',
          'Always allow webpage scaling regardless of author intent.',
          () => currentWebViewModel?.settings?.ignoresViewportScaleLimits ?? false,
          (v) => currentWebViewModel!.settings!.ignoresViewportScaleLimits = v),
      _buildDecimalField('max_zoom', 'Maximum Zoom Scale',
          'Maximum scale factor for zooming.',
          () => currentWebViewModel?.settings?.maximumZoomScale ?? 1.0,
          (val) => currentWebViewModel!.settings!.maximumZoomScale = val),
      _buildDecimalField('min_zoom', 'Minimum Zoom Scale',
          'Minimum scale factor for zooming.',
          () => currentWebViewModel?.settings?.minimumZoomScale ?? 1.0,
          (val) => currentWebViewModel!.settings!.minimumZoomScale = val),
      _buildDecimalField('page_zoom', 'Page Zoom',
          'Scale factor for web view content.',
          () => currentWebViewModel?.settings?.pageZoom ?? 1.0,
          (val) => currentWebViewModel!.settings!.pageZoom = val),

      _buildSectionHeader("Media & Playback", Icons.play_circle),
      _buildSwitch('airplay', 'AirPlay for Media Playback',
          'Enable AirPlay for media content.',
          () => currentWebViewModel?.settings?.allowsAirPlayForMediaPlayback ?? true,
          (v) => currentWebViewModel!.settings!.allowsAirPlayForMediaPlayback = v),
      _buildSwitch('inline_media', 'Inline Media Playback',
          'Allow HTML5 media to play inline within the layout.',
          () => currentWebViewModel?.settings?.allowsInlineMediaPlayback ?? false,
          (v) => currentWebViewModel!.settings!.allowsInlineMediaPlayback = v),
      _buildSwitch('pip', 'Picture in Picture Media Playback',
          'Enable HTML5 videos to play picture-in-picture.',
          () => currentWebViewModel?.settings?.allowsPictureInPictureMediaPlayback ?? true,
          (v) => currentWebViewModel!.settings!.allowsPictureInPictureMediaPlayback = v),

      _buildSectionHeader("Rendering & Performance", Icons.speed),
      _buildSwitch('incremental_render', 'Suppress Incremental Rendering',
          'Wait until content is fully loaded before rendering.',
          () => currentWebViewModel?.settings?.suppressesIncrementalRendering ?? false,
          (v) => currentWebViewModel!.settings!.suppressesIncrementalRendering = v),
      _buildDropdown<SelectionGranularity>('selection_granularity', 'Selection Granularity',
          'Level of granularity for interactive content selection.',
          SelectionGranularity.values.toList(),
          () => currentWebViewModel?.settings?.selectionGranularity,
          (v) => currentWebViewModel!.settings!.selectionGranularity = v),

      _buildSectionHeader("Data & Privacy", Icons.privacy_tip),
      _buildSwitch('shared_cookies', 'Shared Cookies Enabled',
          'Use shared cookies from HTTPCookieStorage for all requests.',
          () => currentWebViewModel?.settings?.sharedCookiesEnabled ?? false,
          (v) => currentWebViewModel!.settings!.sharedCookiesEnabled = v),
      _buildDataDetectorTypes(context),

      _buildSectionHeader("Accessibility", Icons.accessibility),
      _buildSwitch('scroll_insets', 'Auto-Adjust Scroll Indicator Insets',
          'Automatically adjust scroll indicator insets.',
          () => currentWebViewModel?.settings?.automaticallyAdjustsScrollIndicatorInsets ?? false,
          (v) => currentWebViewModel!.settings!.automaticallyAdjustsScrollIndicatorInsets = v),
      _buildSwitch('invert_colors', 'Ignore Invert Colors',
          'Ignore accessibility requests to invert colors.',
          () => currentWebViewModel?.settings?.accessibilityIgnoresInvertColors ?? false,
          (v) => currentWebViewModel!.settings!.accessibilityIgnoresInvertColors = v),
      _buildSwitch('text_interaction', 'Text Interaction Enabled',
          'Enable text interaction capabilities.',
          () => currentWebViewModel?.settings?.isTextInteractionEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isTextInteractionEnabled = v),

      _buildSectionHeader("Advanced Features", Icons.settings_applications),
      _buildSwitch('apple_pay', 'Apple Pay API Enabled',
          'Enable Apple Pay API for the next page load.',
          () => currentWebViewModel?.settings?.applePayAPIEnabled ?? false,
          (v) => currentWebViewModel!.settings!.applePayAPIEnabled = v),
      _buildSwitch('quirks_mode', 'Site Specific Quirks Mode',
          'Apply WebKit built-in compatibility workarounds.',
          () => currentWebViewModel?.settings?.isSiteSpecificQuirksModeEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isSiteSpecificQuirksModeEnabled = v),
      _buildSwitch('upgrade_https', 'Upgrade Known Hosts To HTTPS',
          'Upgrade HTTP requests to known HTTPS servers.',
          () => currentWebViewModel?.settings?.upgradeKnownHostsToHTTPS ?? false,
          (v) => currentWebViewModel!.settings!.upgradeKnownHostsToHTTPS = v),
      _buildSwitch('fullscreen', 'Element Fullscreen Enabled',
          'Enable fullscreen API.',
          () => currentWebViewModel?.settings?.isElementFullscreenEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isElementFullscreenEnabled = v),
      _buildSwitch('find_interaction', 'Find Interaction Enabled',
          'Enable built-in find interaction native UI.',
          () => currentWebViewModel?.settings?.isFindInteractionEnabled ?? false,
          (v) => currentWebViewModel!.settings!.isFindInteractionEnabled = v),
      _buildTextField('media_type', 'Media Type',
          'Media type for the web view contents.',
          () => currentWebViewModel?.settings?.mediaType ?? '',
          (v) => currentWebViewModel!.settings!.mediaType = v.isEmpty ? null : v),
      _buildDropdown<ScrollViewContentInsetAdjustmentBehavior>('content_inset', 'Content Inset Adjustment',
          'How safe area insets are added to adjusted content inset.',
          ScrollViewContentInsetAdjustmentBehavior.values.toList(),
          () => currentWebViewModel?.settings?.contentInsetAdjustmentBehavior,
          (v) => currentWebViewModel!.settings!.contentInsetAdjustmentBehavior = v),
      _buildColorPicker(context, 'bg_color', 'Under Page Background Color',
          'Color displayed behind the active page when scrolling beyond bounds.',
          () => currentWebViewModel?.settings?.underPageBackgroundColor ?? Colors.white,
          (color) => currentWebViewModel!.settings!.underPageBackgroundColor = color),
    ];
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.blue.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String id, String title, String subtitle, bool Function() getValue, void Function(bool) setValue) {
    return GetBuilder<UnifiedSettingsController>(
      tag: 'unified_settings',
      id: id,
      builder: (_) => SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: getValue(),
        onChanged: (v) async {
          if (currentWebViewModel?.settings != null) {
            setValue(v);
            await _applySettings();
          }
        },
      ),
    );
  }

  Widget _buildNumberField(String id, String title, String subtitle, int Function() getValue, void Function(int) setValue) {
    return GetBuilder<UnifiedSettingsController>(
      tag: 'unified_settings',
      id: id,
      builder: (_) => ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: SizedBox(
          width: 60,
          child: TextFormField(
            key: ValueKey(getValue()),
            initialValue: getValue().toString(),
            keyboardType: TextInputType.number,
            onFieldSubmitted: (value) async {
              final int? val = int.tryParse(value);
              if (val != null && currentWebViewModel?.settings != null) {
                setValue(val);
                await _applySettings();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDecimalField(String id, String title, String subtitle, double Function() getValue, void Function(double) setValue) {
    return GetBuilder<UnifiedSettingsController>(
      tag: 'unified_settings',
      id: id,
      builder: (_) => ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: SizedBox(
          width: 80,
          child: TextFormField(
            key: ValueKey(getValue()),
            initialValue: getValue().toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onFieldSubmitted: (value) async {
              final double? val = double.tryParse(value);
              if (val != null && currentWebViewModel?.settings != null) {
                setValue(val);
                await _applySettings();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String id, String title, String subtitle, String Function() getValue, void Function(String) setValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(title: Text(title), subtitle: Text(subtitle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: GetBuilder<UnifiedSettingsController>(
            tag: 'unified_settings',
            id: id,
            builder: (_) => TextFormField(
              key: ValueKey(getValue()),
              initialValue: getValue(),
              onFieldSubmitted: (v) async {
                if (currentWebViewModel?.settings != null) {
                  setValue(v);
                  await _applySettings();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(String id, String title, String subtitle, List<T> values, T? Function() getValue, void Function(T) setValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(title: Text(title), subtitle: Text(subtitle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: GetBuilder<UnifiedSettingsController>(
            tag: 'unified_settings',
            id: id,
            builder: (_) => DropdownButton<T>(
              isExpanded: true,
              value: getValue(),
              hint: Text(title),
              onChanged: (v) async {
                if (v != null && currentWebViewModel?.settings != null) {
                  setValue(v);
                  await _applySettings();
                }
              },
              items: values.map((e) => DropdownMenuItem(value: e, child: Text(e.toString().split('.').last))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(BuildContext context, String id, String title, String subtitle, Color Function() getValue, void Function(Color) setValue) {
    return GetBuilder<UnifiedSettingsController>(
      tag: 'unified_settings',
      id: id,
      builder: (_) => ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: SizedBox(
          width: 140,
          child: ElevatedButton(
            onPressed: () => _showColorPicker(context, getValue(), setValue),
            child: Text(
              getValue().toString(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataDetectorTypes(BuildContext context) {
    return GetBuilder<UnifiedSettingsController>(
      tag: 'unified_settings',
      id: 'data_detectors',
      builder: (_) => ListTile(
        title: const Text("Data Detector Types"),
        subtitle: const Text("Specifying a dataDetectoryTypes value adds interactivity to web content that matches the value."),
        trailing: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2),
          child: Text(
            currentWebViewModel?.settings?.dataDetectorTypes?.map((e) => e.toString().split('.').last).join(", ") ?? "None",
            overflow: TextOverflow.ellipsis,
          ),
        ),
        onTap: () async {
          final selected = await Get.dialog<Set<DataDetectorTypes>>(
            MultiSelectDialog(
              title: const Text("Data Detector Types"),
              items: DataDetectorTypes.values
                  .map((type) => MultiSelectDialogItem<DataDetectorTypes>(
                        value: type,
                        label: type.toString().split('.').last,
                      ))
                  .toList(),
              initialSelectedValues: currentWebViewModel?.settings?.dataDetectorTypes?.toSet() ?? {},
            ),
          );

          if (selected != null && currentWebViewModel?.settings != null) {
            currentWebViewModel!.settings!.dataDetectorTypes = selected.toList();
            await _applySettings();
          }
        },
      ),
    );
  }

  void _showColorPicker(BuildContext context, Color initialColor, void Function(Color) onChanged) {
    Get.dialog(
      AlertDialog(
        title: const Text("Pick a color"),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) async {
              onChanged(color);
              await _applySettings();
            },
            labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Close")),
        ],
      ),
    );
  }
}