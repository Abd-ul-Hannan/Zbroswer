import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/FavoriteController.dart';
import 'package:zbrowser/tools/custom_image.dart';
import 'package:zbrowser/models/browser_model.dart';
import 'package:zbrowser/models/webview_model.dart';
import 'package:zbrowser/models/window_model.dart';
import 'package:zbrowser/screens/webview_tab.dart';
import 'package:zbrowser/database/state_manager.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        StateManager.saveState('/', null);
        return true;
      },
      child: const FavoritesScreenContent(),
    );
  }
}

class FavoritesScreenContent extends StatelessWidget {
  const FavoritesScreenContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) { 
    final favoriteController = Get.find<FavoriteController>();

    // Bind directly to BrowserModel so GetX tracks its observables properly
    return GetX<BrowserModel>(builder: (browserModel) {
      final favorites = browserModel.favorites;

      return Scaffold(
        appBar: _buildAppBar(favoriteController),
        body: favorites.isEmpty
            ? const Center(child: Text('No favorites yet'))
            : ListView.builder(
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  final url = favorite.url;
                  final faviconUrl = favorite.favicon != null
                      ? favorite.favicon!.url
                      : WebUri("${url?.origin ?? ""}/favicon.ico");

                  return _buildFavoriteTile(
                    favorite,
                    faviconUrl,
                    favoriteController,
                    browserModel,
                  );
                },
              ),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(FavoriteController controller) {
    return AppBar(
      leading: Obx(() => controller.isSelectionMode.value
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => controller.cancelSelection(),
            )
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Get.back(),
            )),
      title: Obx(() => Text(
            controller.isSelectionMode.value
                ? '${controller.selectedFavorites.length} selected'
                : 'Favorites',
          )),
      actions: [
        Obx(() => controller.isSelectionMode.value
            ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => controller.deleteSelected(),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildFavoriteTile(
    dynamic favorite,
    WebUri faviconUrl,
    FavoriteController controller,
    BrowserModel browserModel,
  ) {
    return Obx(() {
      final isSelectionMode = controller.isSelectionMode.value;
      final isSelected = controller.selectedFavorites.contains(favorite);

      return ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => controller.toggleSelection(favorite),
              ),
            CustomImage(
              url: faviconUrl,
              maxWidth: 30.0,
              height: 30.0,
            ),
          ],
        ),
        title: Text(
          favorite.title ?? favorite.url?.toString() ?? "",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          favorite.url?.toString() ?? "",
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        selectedTileColor: Colors.blue.withOpacity(0.2),
        isThreeLine: true,
        onTap: () {
          if (isSelectionMode) {
            controller.toggleSelection(favorite);
          } else {
            Get.back();
            _addNewTab(url: favorite.url);
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            controller.startSelectionMode();
            controller.toggleSelection(favorite);
          }
        },
        trailing: isSelectionMode
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 20.0),
                onPressed: () {
                  final title = favorite.title?.isNotEmpty == true 
                      ? favorite.title! 
                      : favorite.url.toString();
                  browserModel.removeFavorite(favorite);
                  Get.snackbar(
                    'Removed',
                    title,
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                  );
                },
              ),
      );
    });
  }

  void _addNewTab({WebUri? url}) {
    final browserModel = Get.find<BrowserModel>();
    final windowModel = Get.find<WindowModel>();
    final settings = browserModel.getSettings();

    url ??= settings.homePageEnabled && settings.customUrlHomePage.isNotEmpty
        ? WebUri(settings.customUrlHomePage)
        : WebUri(settings.searchEngine.url);

    windowModel.addTab(
      WebViewTab(
        key: GlobalKey(),
        webViewModel: WebViewModel(url: url),
      ),
    );
  }
}